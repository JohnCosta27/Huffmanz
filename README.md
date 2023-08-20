# Huffmanz

A simple utility that uses Huffman Encoding to compress ASCII files.

## Usage

You can compile the program using:

```
zig build-exe main.zig
```

### Encoding

To encode a text file you can run the following command:

```
./main encode file_path output_path
```

### Encoding

To decode an encoded file, you can use the following command:

```
./main decode encoded_path output_path
```
