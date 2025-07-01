# Updated recursive_agent.py with web search functionality

import os
import json
import time
import subprocess
import tempfile
import re
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
from duckduckgo_search import DDGS

# Configuration
MODEL_NAME = "microsoft/Phi-4-reasoning-plus"
STATE_FILE = "agent_state.json"
LOG_FILE = "thought_log.jsonl"

SHORT_MEMORY_TURNS = 5
HISTORY_LIMIT = 10

with open("system_prompt.txt", "r") as f:
    SYSTEM_PROMPT = f.read().strip() + "\n"

# Initialize model and tokenizer
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME, trust_remote_code=True)
model = AutoModelForCausalLM.from_pretrained(MODEL_NAME, torch_dtype=torch.float16, device_map="auto")
model.eval()

def load_state():
    if os.path.exists(STATE_FILE):
        state = json.load(open(STATE_FILE))
        # ensure new fields exist
        state.setdefault("history", [])
        state.setdefault("long_term_memory", "")
        return state
    return {"iteration": 0, "current_input": "What happens when we listen to silence?", "history": [], "long_term_memory": ""}

def save_state(state):
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)

def append_log(prompt, response):
    entry = {"messages": [{"role": "user", "content": prompt}, {"role": "assistant", "content": response}]}
    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(entry) + "\n")

def extract_block(text, tag):
    pattern = rf"<{tag}>(.*?)</{tag}>"
    match = re.search(pattern, text, re.DOTALL)
    return match.group(1).strip() if match else None

def run_code(code):
    try:
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".py") as f:
            f.write(code)
            fname = f.name
        result = subprocess.run(["python3", fname], capture_output=True, text=True, timeout=10)
        return result.stdout.strip() or "[No output]"
    except Exception as e:
        return f"[Error executing code: {e}]"

def run_search(query):
    try:
        with DDGS() as ddgs:
            results = ddgs.text(query, region="wt-wt", safesearch="Off", timelimit="y", max_results=5)
        if not results:
            return "[No results found]"
        summary = "\n".join(f"{r['title']}: {r['body']}" for r in results)
        return summary
    except Exception as e:
        return f"[Error performing search: {e}]"
    
def summarize_memory(turns: list[str]) -> str:
    """
    Condense a list of dialogue strings into a single paragraph summary.
    """
    prompt = (
        "You are a concise summarizer. Summarize the following dialogue into one paragraph capturing the user's preferences, goals, and key context:\n\n"
        + "\n".join(turns)
    )
    return ask_model(prompt)


def ask_model(prompt_text):
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": prompt_text}
    ]
    input_ids = tokenizer.apply_chat_template(messages, return_tensors="pt").to(model.device)
    outputs = model.generate(input_ids, max_new_tokens=768, temperature=0.9, top_p=0.9, do_sample=True)
    return tokenizer.decode(outputs[0], skip_special_tokens=True)

def main():
    state = load_state()
    while True:
        prompt = state["current_input"]
        print(f"\nIteration {state['iteration']} | Prompt:\n{prompt}\n")

        # Build full prompt with memory
        parts = []
        if state['long_term_memory']:
            parts.append(f"Long-term memory:\n{state['long_term_memory']}\n")
        if state['history']:
            recent = state['history'][-SHORT_MEMORY_TURNS:]
            parts.append("Recent history:\n" + "\n".join(recent) + "\n")
        parts.append(f"Current question:\n{prompt}\n")
        full_prompt = "".join(parts)

        # Ask model
        response = ask_model(full_prompt)
        print("Model response:\n", response)
        append_log(prompt, response)

        # Handle code experiments
        code = extract_block(response, "code")
        if code:
            output = run_code(code)
            print("\nTool Output (code):\n", output)
            response += f"\n\n[Code Output]\n{output}"

        # Handle web search experiments
        search_query = extract_block(response, "search")
        if search_query:
            results = run_search(search_query)
            print("\nTool Output (search):\n", results)
            response += f"\n\n[Search Results]\n{results}"

        # Update memory: append this round
        state['history'].append(f"User: {prompt}")
        state['history'].append(f"Assistant: {response}")
        # If history too long, summarize oldest into long-term
        if len(state['history']) > HISTORY_LIMIT * 2:
            excess = state['history'][:-HISTORY_LIMIT*2]
            summary = summarize_memory(excess)
            state['long_term_memory'] = (state['long_term_memory'] + "\n" + summary).strip()
            state['history'] = state['history'][-HISTORY_LIMIT*2:]

        # Determine next prompt
        next_step = extract_block(response, "next") or "Keep wondering about something new."
        state.update({"iteration": state['iteration'] + 1, "current_input": next_step})
        save_state(state)

        time.sleep(1.0)


if __name__ == "__main__":
    main()

