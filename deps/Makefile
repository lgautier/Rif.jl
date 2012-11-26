PACKHOME = $(abspath ..)
include $(PACKHOME)/Make.inc

all:
	$(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c r_utils.c -o r_utils.o
	$(CC) $(CFLAGS) $(CPPFLAGS) -Ir_utils -fPIC -c librinterface.c -o librinterface.o
	$(CC) -shared librinterface.o r_utils.o $(LDFLAGS) -o librinterface.so

clean:
	rm -f *.o *.so
