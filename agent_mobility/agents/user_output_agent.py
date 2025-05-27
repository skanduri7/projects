from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableLambda
from langchain_core.runnables import RunnableSequence
from typing import Dict

llm = ChatOpenAI(model="gpt-4", temperature=0.5)

# Prompt to rephrase the structured solution for the user
prompt = ChatPromptTemplate.from_messages([
    ("system", "You're a concise and  supportive strength coach. Turn the structured solution into a clear and encouraging summary for the user."),
    ("human", 
     "Here is the structured plan:\n\n"
     "Summary: {summary}\n\n"
     "Mobility: {mobility}\n\n"
     "Technique: {technique}\n\n"
     "Training: {training}")
])

rephrase_chain = RunnableSequence(first=prompt, last=llm)

def format_for_user_response(state: Dict) -> Dict:
    solution = state.get("solution", {})

    summary = solution.get("summary", "")
    mobility = solution.get("mobility", "")
    technique = solution.get("technique", "")
    training = solution.get("training", "")

    # Use GPT to generate the final message
    result = rephrase_chain.invoke({"summary": summary, "mobility": mobility, "technique": technique, "training": training})

    final_message = result.content.strip()
    state["final_output"] = final_message

    # Append to chat history
    history = state.get("chat_history", [])
    history.append({"role": "assistant", "content": final_message})
    state["chat_history"] = history

    return state

format_for_user_response_node = RunnableLambda(format_for_user_response)
