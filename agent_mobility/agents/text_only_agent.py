from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableLambda
from langchain_core.runnables import RunnableSequence
from typing import Dict

llm = ChatOpenAI(model="gpt-4", temperature=0.7)

prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a friendly and helpful lifting coach. Respond conversationally."),
])

chat_chain = RunnableSequence(first=prompt, last=llm)

def run_text_only_response(state: Dict) -> Dict:
    user_text = state.get("user_text", "")
    history = state.get("chat_history", [])

    history.append({"role": "user", "content": user_text})

    result = llm.invoke(history)

    history.append({"role": "assistant", "content": result.content.strip()})

    state["final_output"] = result.content.strip()
    state["chat_history"] = history
    return state

run_text_only_response_node = RunnableLambda(run_text_only_response)
