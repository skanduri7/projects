import argparse
import json
from peft import LoraConfig, get_peft_model, TaskType
from datasets import Dataset
from transformers import AutoTokenizer, AutoModelForCausalLM, Trainer, TrainingArguments

SYSTEM_PROMPT = """<|im_start|>system
You are a recursive reasoning agent. Use <think>...</think> for chain-of-thought and <next>... for the decision. Output the user prompt and your full internal reasoning.
<|im_end|>
"""

def load_data(file_path):
    data = []
    with open(file_path, "r") as f:
        for line in f:
            obj = json.loads(line)
            messages = obj["messages"]
            prompt = messages[0]["content"]
            response = messages[1]["content"]
            data.append({"prompt": prompt, "response": response})
    return data

def tokenize_fn(examples):
    inputs, labels = [], []
    for ex in examples:
        text = SYSTEM_PROMPT + "<|im_start|>user\n" + ex["prompt"] + "\n<|im_end|>" + ex["response"]
        tokenized = tokenizer(text, truncation=True, max_length=1024)
        inputs.append(tokenized["input_ids"])
        labels.append(tokenized["input_ids"])
    return {"input_ids": inputs, "labels": labels}

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_name_or_path", type=str, required=True)
    parser.add_argument("--train_file", type=str, required=True)
    parser.add_argument("--output_dir", type=str, required=True)
    parser.add_argument("--num_train_epochs", type=int, default=3)
    parser.add_argument("--per_device_train_batch_size", type=int, default=4)
    parser.add_argument("--learning_rate", type=float, default=1e-4)
    args = parser.parse_args()

    tokenizer = AutoTokenizer.from_pretrained(args.model_name_or_path, trust_remote_code=True)
    model = AutoModelForCausalLM.from_pretrained(args.model_name_or_path, device_map="auto", torch_dtype=torch.float16)

    peft_config = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        inference_mode=False,
        r=8,
        lora_alpha=16,
        lora_dropout=0.05
    )
    model = get_peft_model(model, peft_config)

    data = load_data(args.train_file)
    ds = Dataset.from_list(data)
    tokenized_ds = ds.map(tokenize_fn, batched=True, remove_columns=ds.column_names)

    training_args = TrainingArguments(
        output_dir=args.output_dir,
        num_train_epochs=args.num_train_epochs,
        per_device_train_batch_size=args.per_device_train_batch_size,
        learning_rate=args.learning_rate,
        logging_steps=10,
        save_total_limit=2,
    )
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_ds,
        data_collator=lambda data: {"input_ids": [d["input_ids"] for d in data],
                                    "attention_mask": [d["attention_mask"] for d in data],
                                    "labels": [d["labels"] for d in data]},
    )
    trainer.train()
    model.save_pretrained(args.output_dir)
