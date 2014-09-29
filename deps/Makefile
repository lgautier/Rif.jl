PACKHOME = $(abspath ..)
include $(PACKHOME)/Make.inc

all:
	$(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c r_utils.c -o r_utils.o
	$(CC) $(CFLAGS) $(CPPFLAGS) -lreadline -Ir_utils -fPIC -c librinterface.c -o librinterface.o
	$(CC) -lreadline -shared librinterface.o r_utils.o $(LDFLAGS) -o $(SHAREDLIBNAME)

clean:
	rm -f *.o *.so *.dylib
