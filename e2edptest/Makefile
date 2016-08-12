TARGET =  metagen 
SRCS   =  metagen.o crct10dif_common.o

CFLAGS :=  
LDFLAGS := 

OBJS=$(SRCS:.c=.o)

.SUFFIXES: .c .o

# .PHONY: all clean

.c.o:
	@echo "Compiling $< ..."
	@$(RM) $@
	$(CC) -Wall -c -O2 -D_GNU_SOURCE $(CFLAGS) -o $@ $<

$(TARGET):     $(OBJS)
	@echo "Making ./$(TARGET) ..."
	@echo "$(CC) -o $@ $(OBJS) $(LDFLAGS)"
	@$(CC) -o $@ $(OBJS) $(LIBS) $(LDFLAGS)
	

all:    $(TARGET)

clean:
	rm -f *.o *.a *~ $(TARGET)

uninstall:
