CC=            gcc
R=             R
CPPFLAGS =     `${R} CMD config --cppflags`
CFLAGS=        -Wall
LDFLAGS=       `${R} CMD config --ldflags`

SRC=           deps/

all:
	cd $(SRC) && $(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c librinterface.c -o librinterface.o
	cd $(SRC) && $(CC) -shared librinterface.o $(LDFLAGS) -o librinterface.so

clean:
	cd $(SRC) && rm -f *.o *.so
