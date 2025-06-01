# tracker.py
import cv2
import mediapipe as mp
import socket
import json
import math


mp_hands = mp.solutions.hands
hands = mp_hands.Hands(static_image_mode=False, 
                       max_num_hands=1,
                       min_detection_confidence=0.5,
                       min_tracking_confidence=0.5)


HOST = '127.0.0.1'
PORT = 65432        
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind((HOST, PORT))
s.listen()
print(f"Listening on {HOST}:{PORT}")
conn, addr = s.accept()
print(f"Connected by {addr}")


cap = cv2.VideoCapture(0)

PINCH_THRESHOLD = 0.1

def distance(a, b):
    dx = a.x - b.x
    dy = a.y - b.y
    return math.hypot(dx, dy)

prev_pen_down = False

try:
    while cap.isOpened():
        success, image = cap.read()
        if not success:
            continue

        # Flip cuz selfie mode.
        image = cv2.flip(image, 1)

        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        results = hands.process(image_rgb)
        
        pen_down = False
        x, y = None, None

#        if results.multi_hand_landmarks:
#            for hand_landmarks in results.multi_hand_landmarks:
#
#                # index finger tip coordinates
#                x = hand_landmarks.landmark[8].x
#                y = hand_landmarks.landmark[8].y
#                data = json.dumps({'x': x, 'y': y})
#                conn.sendall(data.encode('utf-8'))
        if results.multi_hand_landmarks and results.multi_handedness:
            # We’ll look for the RIGHT hand specifically
            for hand_landmarks, handedness in zip(results.multi_hand_landmarks,
                                                  results.multi_handedness):
                label = handedness.classification[0].label  # “Left” or “Right”
                if label == "Right":
                    lm = hand_landmarks.landmark
                    thumb_tip  = lm[4]
                    index_tip  = lm[8]
                    middle_tip = lm[12]

                    # Check if all three fingertips are within PINCH_THRESHOLD
                    d1 = distance(thumb_tip, index_tip)
                    d2 = distance(thumb_tip, middle_tip)
                    d3 = distance(index_tip, middle_tip)

                    if d1 < PINCH_THRESHOLD and d2 < PINCH_THRESHOLD and d3 < PINCH_THRESHOLD:
                        pen_down = True
                        x, y = index_tip.x, index_tip.y
                    break  # only use first right hand
                    
        if pen_down:
            data = {'down': True, 'x': x, 'y': y}
        else:
            # Only send an “up” event once when we transition
            if prev_pen_down:
                data = {'down': False}
            else:
                data = None

        if data:
            conn.sendall(json.dumps(data).encode('utf-8'))

        prev_pen_down = pen_down


finally:
    cap.release()
    s.close()
    cv2.destroyAllWindows()
