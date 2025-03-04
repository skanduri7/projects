all: vmscheduler

vmscheduler: src/main.o src/memory.o src/scheduler.o src/process.o
	gcc -o vmscheduler src/main.o src/memory.o src/scheduler.o src/process.o

main.o: src/main.c include/memory.h include/scheduler.h include/process.h
	gcc -c src/main.c

memory.o: src/memory.c include/memory.h
	gcc -c src/memory.c

scheduler.o: src/scheduler.c include/scheduler.h
	gcc -c src/scheduler.c

process.o: src/process.c include/process.h
	gcc -c src/process.c

clean:
	rm -f *.o vmscheduler
