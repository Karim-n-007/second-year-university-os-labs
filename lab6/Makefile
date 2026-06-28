CXX      = g++
CXXFLAGS = -Wall -Wextra -O2 -std=c++17
TARGET   = fuse_convert
SRC      = fuse_convert.cpp

FUSE_CFLAGS = $(shell pkg-config fuse3 --cflags)
FUSE_LIBS   = $(shell pkg-config fuse3 --libs)

all: $(TARGET)

$(TARGET): $(SRC)
	$(CXX) $(CXXFLAGS) $(FUSE_CFLAGS) -o $@ $< $(FUSE_LIBS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
