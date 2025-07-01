import json

LOG_FILE = "thought_log.jsonl"
OUTPUT_FILE = "finetune_data.jsonl"
TOP_K = 500  # Number of samples to select

def main():
    entries = []
    with open(LOG_FILE, "r") as f:
        for line in f:
            entries.append(json.loads(line))
    selected = entries[-TOP_K:]
    with open(OUTPUT_FILE, "w") as f:
        for e in selected:
            f.write(json.dumps(e) + "\n")
    print(f"Wrote {len(selected)} samples to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
