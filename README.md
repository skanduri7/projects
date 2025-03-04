# 📌 Projects Repository
Welcome to the Projects Repository, a collection of systems programming, machine learning, and optimization projects. Each project focuses on improving efficiency, performance, or understanding core concepts in operating systems, parallel computing, and AI.

📂 Project Overview
This repository consists of several projects, each targeting different areas of computer science.

🛠 Custom User-Space Filesystem
📌 Location: custom-fs/
📅 Feb 2025 – Present

A user-space filesystem built using FUSE (Filesystem in Userspace). This project focuses on custom metadata management, file handling, and debugging system call behavior.

Key Features:
✔️ Implements a fully functional user-space filesystem
✔️ Supports directory operations (list, navigate)
✔️ Debugging of file creation (touch) to ensure metadata persistence
✔️ Uses kernel-user space debugging techniques for syscall analysis

🖥️ OS-Level Process Scheduler
📌 Location: vmscheduler/
📅 Jan 2025

A preemptive priority-based scheduler implemented in C, designed to optimize CPU utilization for OS-level process management.

Key Features:
✔️ Dynamically recalculates priorities for CPU-bound processes
✔️ Enforces strict priority scheduling to ensure efficiency
✔️ Exploring multi-threading and cache locality optimizations for better real-time scheduling

🤖 Custom GPT Language Model
📌 Location: custom-gpt-language-model/
📅 Aug - Sept 2024

A deep dive into transformer-based AI models, implementing core GPT-like architectures from scratch using tensor operations and CUDA.

Key Features:
✔️ Implemented core modules: Linear, LayerNorm, Embeddings, MultiHeadAttention, FeedForward
✔️ Optimized for GPU execution with CUDA in Google Colab
✔️ Custom-built Dropout and LayerNorm for enhanced performance
✔️ Designed to learn from large text corpora and generate coherent text

🎥 Optimized Convolutions for Video Processing
📌 Location: optimized-convolutions/
📅 May 2024

Optimized 2D convolution operations for video processing, leveraging multi-threading, OpenMP, and SIMD acceleration.

Key Features:
✔️ Achieved 8× speedup in performance testing
✔️ Implemented OpenMP multi-threading for better CPU utilization
✔️ Developed an OpenMPI coordinator to distribute tasks across multiple processes
✔️ Used SIMD (AVX intrinsics) for vectorized parallel processing

🚀 Getting Started
🔧 Cloning the Repository
bash
Copy
Edit
git clone https://github.com/skanduri7/projects.git
cd projects
💡 Running Projects
Each project contains specific build instructions. Navigate to a project directory and follow its README or Makefile for execution.

Example for optimized-convolutions:

bash
Copy
Edit
cd optimized-convolutions
make
./run_convolution

