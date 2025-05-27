import json
from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableLambda
from langchain_core.runnables import RunnableSequence
from typing import Dict

llm = ChatOpenAI(model="gpt-4", temperature=0.3)

prompt = ChatPromptTemplate.from_messages([
    ("system", "You're a brutally honest strength coach. Based on the lifter's profile and session summary, create:\n"
     "- A blunt, truthful summary of what’s wrong\n"
     "- Specific action items for: mobility, technique, and training.\n"
     "Respond as JSON with keys: 'summary', 'mobility', 'technique', 'training'."),
    ("human", "Lifter Profile:\n{lifter_profile}\n\nSession Summary:\n{session_summary}")
])

solution_chain = RunnableSequence(first=prompt, last=llm)

def run_solution_generator(state: Dict) -> Dict:
    lifter_profile = state.get("lifter_profile", "")
    session_summary = state.get("session_summary", "")

    if not lifter_profile or not session_summary:
        raise ValueError("Missing input for solution generation.")

    result = solution_chain.invoke({"lifter_profile": lifter_profile, "session_summary": session_summary})

    try:
        solution = json.loads(result.content)
    except json.JSONDecodeError:
        solution = {
            "summary": "Could not parse full response. Raw output:",
            "raw": result.content.strip()
        }

    # Store structured solution + blunt summary for next agent
    state["solution"] = solution
    state["final_output"] = solution.get("summary", "No summary provided.")
    return state

run_solution_generator_node = RunnableLambda(run_solution_generator)
