from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableLambda
from langchain_core.runnables import RunnableSequence
from typing import Dict
import os

llm = ChatOpenAI(model="gpt-4", temperature=0.3)

prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a strength and conditioning coach. Given a lifter's session history, summarize their overall profile including consistent patterns, strengths, weaknesses, mobility or technique issues, and progress over time."),
    ("human", "{full_history}")
])

diagnosis_chain = RunnableSequence(first=prompt, last=llm)

def load_history_logs(log_dir="history_logs", max_logs=10) -> str:
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    log_path = os.path.join(project_root, log_dir)
    os.makedirs(log_path, exist_ok=True)

    history = []
    log_files = sorted([f for f in os.listdir(log_path) if f.endswith(".txt")], reverse=True)[:max_logs]

    for log_file in log_files:
        with open(os.path.join(log_path, log_file), "r") as f:
            content = f.read()
            history.append(f"--- Log File: {log_file} ---\n{content.strip()}")

    return "\n\n".join(history)

def run_lifter_profile(state: Dict) -> Dict:
    full_history_text = load_history_logs()
    current_session = "\n".join([
        f"Text Summary:\n{state.get('text_summary', '')}",
        f"Video Summary:\n{state.get('video_summary', '')}",
        f"Session Summary:\n{state.get('session_summary', '')}"
    ]).strip()

    if full_history_text.strip():
        combined_input = f"{full_history_text}\n\n--- Current Session ---\n{current_session}"
    else:
        combined_input = f"--- Current Session ---\n{current_session}"

    result = diagnosis_chain.invoke({"full_history": combined_input})

    lifter_profile = result.content.strip()

    state["lifter_profile"] = lifter_profile
    return state

run_lifter_profile_node = RunnableLambda(run_lifter_profile)
