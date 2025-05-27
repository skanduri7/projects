import tempfile
import streamlit as st
import os
from dotenv import load_dotenv
load_dotenv()
from datetime import datetime
from main import app  # your compiled LangGraph app

# Initialize session state
if "agent_state" not in st.session_state:
    st.session_state.agent_state = {
        "user_text": "",
        "video_path": "",
        "text_summary": None,
        "video_summary": None,
        "session_summary": None,
        "lifter_profile": None,
        "solution": None,
        "final_output": None,
        "exit": False,
        "chat_history": [],
        "text_only": False
    }

st.title("Lifter AI Assistant")

with st.form("input_form"):
    user_text = st.text_area("Describe your issue or goal", placeholder="Type here...")
    uploaded_video = st.file_uploader("Upload a video file (recommended)", type=["mp4", "mov", "avi", "mkv"])

    submit = st.form_submit_button("Submit")

if submit:
    video_path = ""
    if uploaded_video:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as temp_video:
            temp_video.write(uploaded_video.read())
            video_path = temp_video.name

    st.session_state.agent_state["user_text"] = user_text
    st.session_state.agent_state["video_path"] = video_path


    result = app.invoke(st.session_state.agent_state)


    st.session_state.agent_state = result

    # Display result
    st.subheader("AI Assistant Output")
    st.write(result.get("final_output", "No output generated."))

    if video_path:
        log_data = {
        "timestamp": datetime.now().isoformat(),
        "text_summary": result.get("text_summary", "No text provided"),
        "video_summary": result.get("video_summary", "No video provided"),
        "session_summary": result.get("session_summary", ""),
        "solution": result.get("solution", {}),
        }

        log_dir = "history_logs"
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, f"log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")

        with open(log_file, "w") as f:
            for key, value in log_data.items():
                f.write(f"{key}:\n{value}\n\n")

    st.session_state.agent_state["user_text"] = ""
    st.session_state.agent_state["video_path"] = ""
    st.session_state.agent_state["text_summary"] = None
    st.session_state.agent_state["video_summary"] = None
    st.session_state.agent_state["session_summary"] = None
    st.session_state.agent_state["solution"] = None
    st.session_state.agent_state["final_output"] = None


    if result.get("exit", True):
        st.success("Session complete. Refresh to restart.")
