from typing import Dict
import cv2
import mediapipe as mp
import base64
import json
from openai import OpenAI
from langchain_openai import ChatOpenAI
from langchain_core.runnables import RunnableLambda


client = OpenAI()

llm = ChatOpenAI(model="gpt-4", temperature=0.4)

def extract_frames(video_path, frame_interval=5):
    cap = cv2.VideoCapture(video_path)
    frames = []
    frame_idx = 0
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        if frame_idx % frame_interval == 0:
            frames.append(frame)
        frame_idx += 1
    cap.release()
    return frames


def estimate_pose(frames, draw=False):
    mp_pose = mp.solutions.pose
    mp_drawing = mp.solutions.drawing_utils
    pose = mp_pose.Pose(static_image_mode=True)
    results_list = []
    overlayed_frames = [] if draw else None

    for idx, frame in enumerate(frames):
        image_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        result = pose.process(image_rgb)

        joints = {}
        if result.pose_landmarks:
            for i, lm in enumerate(result.pose_landmarks.landmark):
                joints[mp_pose.PoseLandmark(i).name] = {"x": lm.x, "y": lm.y, "z": lm.z, "visibility": lm.visibility}
            if draw:
                annotated_image = frame.copy()
                mp_drawing.draw_landmarks(annotated_image, result.pose_landmarks, mp_pose.POSE_CONNECTIONS)
                overlayed_frames.append(annotated_image)
        else:
            joints = {"error": "No pose detected"}
            if draw:
                overlayed_frames.append(frame)

        results_list.append({"frame_index": idx, "joints": joints})

    pose.close()
    return (results_list, overlayed_frames) if draw else results_list

def encode_image_to_base64(image):
    _, buffer = cv2.imencode('.jpg', image)
    encoded = base64.b64encode(buffer).decode('utf-8')
    return f"data:image/jpeg;base64,{encoded}"


def run_video_agent_node(state: Dict) -> Dict:
    video_path = state.get("video_path")
    if not video_path:
        state["video_summary"] = "No video provided."
        return state

    orig_frames = extract_frames(state["video_path"])

    pose_data, annot_frames = estimate_pose(orig_frames, draw=True)

    sampled_indices = [0, len(annot_frames) // 3, 2 * len(annot_frames) // 3]
    context_examples = []

    for i in sampled_indices:
        joints = pose_data[i]["joints"]
        img_b64 = encode_image_to_base64(annot_frames[i])
        context_examples.append({"image": img_b64, "joints": joints, "frame_index": pose_data[i]["frame_index"]})

    messages_pass1 = [{"role": "system", "content": "You are a biomechanics coach. Understand the movement being performed."}]
    for ex in context_examples:
        messages_pass1.append({"role": "user",
            "content": [
                {"type": "image_url", "image_url": {"url": ex["image"], "detail": "high"}},
                {"type": "text", "text": f"Frame {ex['frame_index']} pose data:\n{json.dumps(ex['joints'], indent=2)}"}
            ]
        })
    messages_pass1.append({
        "role": "user",
        "content": "Based on these frames, describe:\n"
        "- What exercise is being performed?\n"
        "- The movement phases.\n"
        "- The overall goal of the movement.\n"
    })

    pass1_response = client.chat.completions.create(model="gpt-4o", messages=messages_pass1, max_tokens=700)

    movement_understanding = pass1_response.choices[0].message.content

    all_feedback = []
    summaries = []
    for i, (frame_data, annotated_frame) in enumerate(zip(pose_data, annot_frames)):
        if i % 10 != 0:
            continue
        joints = frame_data["joints"]
        frame_index = frame_data["frame_index"]
        image_b64 = encode_image_to_base64(annotated_frame)

        messages = [
            {"role": "system", "content": "You are a biomechanics and strength coach. Use both image and joint data to create detailed observations."},
            {"role": "user", "content": f"Context: {movement_understanding}"},
            {"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": image_b64, "detail": "high"}},
                {"type": "text", "text": (
                    f"This is frame {frame_index} of the lift.\n"
                    f"Joint data:\n{json.dumps(joints, indent=2)}\n\n"
                    "Analyze this frame and provide:\n"
                    "- What phase of the lift is occurring? How critical is this?\n"
                    "- Posture/alignment issues?\n"
                    "- Technique feedback and coaching tips."
                )}
            ]}
        ]

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=messages,
            max_tokens=600
        )

        frame_feedback = response.choices[0].message.content
        all_feedback.append(f"Frame {frame_index} Feedback:\n{frame_feedback}\n")

        if i > 0 and i % 100:
            combined_feedback = "\n".join(all_feedback)
            summary_prompt = (
                "You are a biomechanical coach. Summarize the following frame-by-frame lifting technique analysis.\n"
                "Create a structured summary that includes:\n"
                "- Strengths\n"
                "- Weaknesses\n"
                "- Common patterns\n"
                "- Critical points\n\n"
                "Here is the frame-by-frame analysis:\n"
                f"{combined_feedback}"
            )

            summary_response = client.chat.completions.create(model="gpt-4-1106-preview",
                    messages=[
                        {"role": "system", "content": "You are a biomechanics expert summarizing detailed form feedback."},
                        {"role": "user", "content": summary_prompt}
                        ],
                    max_tokens=4000
                    )
            curr_video_summary = summary_response.choices[0].message.content
            summaries.append(curr_video_summary)
            all_feedback = []

    summary_prompt = (
        "You are a biomechanical coach. You are given the following summaries of a video which are sequential.\n"
        "Create a structured overal summary that includes:\n"
        "- Strengths\n"
        "- Weaknesses\n"
        "- Common patterns\n"
        "- Critical points\n\n"
        "Here is the frame-by-frame analysis:\n"
        f"{summaries}"
    )

    summary_response = client.chat.completions.create(model="gpt-4-1106-preview",
                    messages=[
                        {"role": "system", "content": "You are a biomechanics expert summarizing detailed form feedback."},
                        {"role": "user", "content": summary_prompt}
                        ],
                    max_tokens=4000)
    video_summary = summary_response.choices[0].message.content
    
    state["video_summary"] = video_summary
    return state

run_video_llm_agent_node = RunnableLambda(run_video_agent_node)