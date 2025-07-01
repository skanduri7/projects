#!/bin/bash

# Fine-tune Phi-4-Reasoning+ with LoRA using Hugging Face PEFT

MODEL_NAME="microsoft/Phi-4-Reasoning-plus"
DATA_FILE="finetune_data.jsonl"
OUTPUT_DIR="phi4_lora"
EPOCHS=3
BATCH_SIZE=4

accelerate launch --config_file ./accelerate_config.yaml train_lora.py \
  --model_name_or_path $MODEL_NAME \
  --train_file $DATA_FILE \
  --output_dir $OUTPUT_DIR \
  --num_train_epochs $EPOCHS \
  --per_device_train_batch_size $BATCH_SIZE \
  --learning_rate 1e-4 \
  --lora_r 8 \
  --lora_alpha 16 \
  --lora_dropout 0.05
