from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableLambda
from langchain_core.runnables import RunnableSequence
from typing import Dict

# Use GPT-4 for better synthesis
llm = ChatOpenAI(model="gpt-4", temperature=0.3)

# Prompt to merge text and video summaries into a full session summary
prompt = ChatPromptTemplate.from_messages([
    ("system", "You are an expert lifting coach. Combine the user's description and the video analysis into one high-level summary of the session. Focus on overall context, key observations, and performance issues."),
    ("human", "Text Summary:\n{text_summary}\n\nVideo Summary:\n{video_summary}")
])

fusion_chain = RunnableSequence(first=prompt, last=llm)

def run_input_fusion(state: Dict) -> Dict:
    text_summary = state.get("text_summary", "")
    video_summary = state.get("video_summary", "")

    if not (text_summary or video_summary):
        raise ValueError("Missing summaries for input fusion.")

    result = fusion_chain.invoke({"text_summary": text_summary, "video_summary": video_summary})

    session_summary = result.content.strip()
    state["session_summary"] = session_summary

    # session_summary_msg = {"role": "assistant", "content": f"Here's a summary of what we gathered from your session:\n\n{session_summary}"}

    # history = state.get("chat_history", [])
    # history.append(session_summary_msg)
    # state["chat_history"] = history
    return state

run_input_fusion_node = RunnableLambda(run_input_fusion)
