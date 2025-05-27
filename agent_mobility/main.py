from typing import Optional, TypedDict
from langgraph.graph import StateGraph, END
from langchain_core.runnables import RunnableLambda
import os, json

from agents.text_agent import run_text_agent_node
from agents.video_agent import run_video_llm_agent_node
from agents.input_analysis_agent import run_input_fusion_node
from agents.lifter_profile_agent import run_lifter_profile_node
from agents.lifter_solution_agent import run_solution_generator_node
from agents.text_only_agent import run_text_only_response_node
from agents.user_output_agent import format_for_user_response_node

class AgentState(TypedDict):
    user_text: str
    video_path: str
    text_summary: Optional[str]
    video_summary: Optional[str]
    session_summary: Optional[str]
    lifter_profile: Optional[str]
    solution: Optional[dict]
    final_output: Optional[str]
    exit: bool
    chat_history: Optional[list]
    text_only: bool



def start_decision(state):
    if state.get("exit", False):
        return "end"
    elif state.get("text_only", False):
        return "text_only"
    else:
        return "continue"

def handle_start_node(state):
    user_text = state.get("user_text", "").strip().lower()
    state["exit"] = (user_text == "exit")
    state["text_only"] = not bool(state.get("video_path"))
    return state


start_node_runnable = RunnableLambda(handle_start_node)

builder = StateGraph(AgentState)

builder.add_node("start_node", start_node_runnable)
builder.add_node("text_only_agent", run_text_only_response_node)
builder.add_node("text_agent", run_text_agent_node)
builder.add_node("video_agent", run_video_llm_agent_node)
builder.add_node("input_fusion_node", run_input_fusion_node)
builder.add_node("lifter_profile_node", run_lifter_profile_node)
builder.add_node("solution_generator", run_solution_generator_node)
builder.add_node("user_output_node", format_for_user_response_node)

builder.set_entry_point("start_node")

builder.add_conditional_edges("start_node", start_decision, 
{
    "text_only": "text_only_agent",
    "continue": "text_agent",
    "end": END
})
builder.add_edge("text_only_agent", END)

builder.add_edge("text_agent", "video_agent")
builder.add_edge("video_agent", "input_fusion_node")
builder.add_edge("input_fusion_node", "lifter_profile_node")
builder.add_edge("lifter_profile_node", "solution_generator")
builder.add_edge("solution_generator", "user_output_node")
builder.add_edge("user_output_node", END)

app = builder.compile()

