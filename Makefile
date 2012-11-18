CC=            gcc
R=             R
CPPFLAGS =     `${R} CMD config --cppflags`
CFLAGS=        -Wall
LDFLAGS=       `${R} CMD config --ldflags`

SRC=           src/

all:
	cd $(SRC) && $(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c librinterface.c -o librinterface.o
	cd $(SRC) && $(CC) -shared librinterface.o $(LDFLAGS) -o librinterface.so
	#test
	cd $(SRC) && $(CC) $(CFLAGS) $(CPPFLAGS) -fPIC -c test.c -o test.o
	cd $(SRC) && $(CC) -shared test.o $(LDFLAGS) -o test.so

clean:
	cd $(SRC) && rm *.o *.so
