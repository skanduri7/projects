from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.runnables import RunnableSequence
from langchain_core.runnables import RunnableLambda
from typing import Dict

# Initialize GPT-4
llm = ChatOpenAI(model="gpt-4", temperature=0.3)

# Define a prompt for summarization
prompt = ChatPromptTemplate.from_messages([
    ("system", "You are a domain-specific assistant. Detail the user's input clearly and concisely."),
    ("human", "{input_text}")
])

# Build the chain
summarization_chain = RunnableSequence(first=prompt, last=llm)

# Function to run in LangGraph
def run_text_agent(state: Dict) -> Dict:
    user_text = state.get("user_text", "").strip()

    response = summarization_chain.invoke({"input_text": user_text})
    text_summary = response.content.strip()

    history = state.get("chat_history", [])
    history.append({"role": "user", "content": user_text})
    state["text_summary"] = text_summary
    return state

# LangGraph-compatible runnable node
run_text_agent_node = RunnableLambda(run_text_agent)
