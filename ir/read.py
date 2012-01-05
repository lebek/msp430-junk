from serial import Serial
from struct import unpack

if __name__ == "__main__":
    from sys import stdout, argv

    s = Serial(argv[1], 9600)

    count = 0
    stdout.write("[%d]" % (count,))
    while True:
        word = s.read(2)
        if word == '\x00\x00':
            count += 1
            stdout.write("\n---\n")
            stdout.write("[%d]" % (count,))
        else:
            stdout.write(" %d" % (unpack("H", word)[0]/1300,))
            stdout.flush()

