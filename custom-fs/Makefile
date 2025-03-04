# Compiler
CC = gcc

# FUSE Library
FUSE_FLAGS = `pkg-config --cflags --libs fuse`  # Auto-detect FUSE settings

# Directories
SRC_DIR = src
INC_DIR = include
BUILD_DIR = build

# Source files
SRCS = $(SRC_DIR)/fs.c $(SRC_DIR)/storage.c $(SRC_DIR)/metadata.c $(SRC_DIR)/cache.c

# Object files
OBJS = $(BUILD_DIR)/fs.o $(BUILD_DIR)/storage.o $(BUILD_DIR)/metadata.o $(BUILD_DIR)/cache.o

# Output binary
TARGET = my_fs

# Compilation flags
CFLAGS = -Wall -Wextra -I$(INC_DIR) -L/usr/local/lib

# Create build directory if it doesn't exist
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile each source file into an object file
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Link all object files into the final binary
$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(FUSE_FLAGS)

# Run the file system
run: $(TARGET)
	./$(TARGET) mountpoint

# Unmount the file system
unmount:
	fusermount -u mountpoint || umount mountpoint

# Clean build files
clean:
	rm -rf $(BUILD_DIR) $(TARGET)
