'use strict';

const fs = require('fs');

const TAPE_SIZE = 30000;
const IO_BUFFER_SIZE = 8192;
const NEWLINE = 10;

const USAGE = `Uso: bf <código | arquivo.bf>

  bf '++++++++[>++++++++<-]>+.'    executa o código passado como texto
  bf caminho/programa.bf           executa um arquivo .bf
  bf -h, bf --help                 mostra esta ajuda

Use sempre aspas simples no código: < > e [ são especiais nos shells.
Código passado como texto só pode conter os comandos + - < > [ ] , . e espaços.
`;

// Errors caused by the user's input or program. They are shown without a stack trace.
class BfError extends Error {}

function locate(code, index) {
    const before = code.slice(0, index).split('\n');
    return `linha ${before.length}, coluna ${before[before.length - 1].length + 1}`;
}

// Maps each bracket to the index of its pair. Also rejects unbalanced programs before they run.
function buildJumpTable(code) {
    const jumps = new Int32Array(code.length);
    const openLoops = []; // Stack that stores the index of open loops.

    for (let i = 0; i < code.length; i++) {
        if (code[i] === '[') {
            openLoops.push(i);
        } else if (code[i] === ']') {
            if (openLoops.length === 0) {
                throw new BfError(`erro de sintaxe: ']' sem '[' correspondente (${locate(code, i)})`);
            }
            const open = openLoops.pop();
            jumps[open] = i;
            jumps[i] = open;
        }
    }

    if (openLoops.length > 0) {
        const open = openLoops[openLoops.length - 1];
        throw new BfError(`erro de sintaxe: '[' sem ']' correspondente (${locate(code, open)})`);
    }
    return jumps;
}

// Non-blocking stdio can report EAGAIN. Waits a little before retrying instead of spinning.
function sleep(ms) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function createOutput(fd) {
    const buffer = Buffer.allocUnsafe(IO_BUFFER_SIZE);
    let length = 0;

    function flush() {
        let offset = 0;
        while (offset < length) {
            try {
                offset += fs.writeSync(fd, buffer, offset, length - offset);
            } catch (err) {
                if (err.code !== 'EAGAIN') throw err;
                sleep(10);
            }
        }
        length = 0;
    }

    function writeByte(byte) {
        buffer[length++] = byte;
        if (byte === NEWLINE || length === buffer.length) flush();
    }

    return { writeByte, flush };
}

function createInput(fd) {
    const buffer = Buffer.allocUnsafe(IO_BUFFER_SIZE);
    let position = 0;
    let length = 0;
    let reachedEnd = false;

    function fill() {
        for (;;) {
            try {
                return fs.readSync(fd, buffer, 0, buffer.length, null);
            } catch (err) {
                if (err.code === 'EOF') return 0;
                if (err.code !== 'EAGAIN') throw err;
                sleep(10);
            }
        }
    }

    // Returns the next stdin byte, or 0 once stdin has ended.
    return function readByte() {
        if (position < length) return buffer[position++];
        if (reachedEnd) return 0;

        length = fill();
        position = 0;
        if (length === 0) {
            reachedEnd = true;
            return 0;
        }
        return buffer[position++];
    };
}

function runBrainfuck(code, output, readByte) {
    const jumps = buildJumpTable(code);
    const memory = new Uint8Array(TAPE_SIZE); // Uint8Array wraps cell values at 8 bits.
    let ptr = 0; // Pointer -> Points to the cell that is currently being manipulated.
    let ip = 0;  /* Instruction Pointer -> Points to the current character in the Brainfuck code
                 and is used by the interpreter to process the code one command at a time. */

    while (ip < code.length) {
        switch (code[ip]) {
            case '>':
                if (++ptr === TAPE_SIZE) {
                    throw new BfError(`erro de execução: ponteiro passou do fim da fita (${locate(code, ip)})`);
                }
                break;
            case '<':
                if (--ptr < 0) {
                    throw new BfError(`erro de execução: ponteiro passou do início da fita (${locate(code, ip)})`);
                }
                break;
            case '+': memory[ptr]++; break;
            case '-': memory[ptr]--; break;
            case '.': output.writeByte(memory[ptr]); break;
            case ',':
                output.flush(); // Shows any pending prompt before waiting for input.
                memory[ptr] = readByte();
                break;
            case '[':
                if (memory[ptr] === 0) ip = jumps[ip];
                break;
            case ']':
                if (memory[ptr] !== 0) ip = jumps[ip];
                break;
            default: break; // Any other character is a comment.
        }
        ip++;
    }
}

function loadProgram(arg) {
    if (/\.bf$/i.test(arg)) {
        try {
            return fs.readFileSync(arg, 'utf8');
        } catch (err) {
            if (err.code === 'ENOENT') throw new BfError(`arquivo não encontrado: ${arg}`);
            throw new BfError(`não foi possível ler ${arg}: ${err.message}`);
        }
    }
    if (/^[+\-<>\[\],.\s]+$/.test(arg)) return arg;
    throw new BfError(`"${arg}" não é um arquivo .bf nem código Brainfuck válido`);
}

function main(args) {
    if (args.length === 0) {
        process.stderr.write(USAGE);
        return 1;
    }
    if (args[0] === '-h' || args[0] === '--help') {
        process.stdout.write(USAGE);
        return 0;
    }

    const output = createOutput(process.stdout.fd);
    try {
        if (args.length > 1) {
            throw new BfError('espera um único argumento. Coloque o código entre aspas simples.');
        }
        try {
            runBrainfuck(loadProgram(args[0]), output, createInput(process.stdin.fd));
        } finally {
            output.flush(); // Keeps what the program printed before a runtime error.
        }
        return 0;
    } catch (err) {
        // The reader of the output went away (e.g. `bf x.bf | head`). That is not a failure.
        if (err.code === 'EPIPE' || err.code === 'EOF') return 0;
        process.stderr.write(`bf: ${err.message}\n`);
        return 1;
    }
}

process.exitCode = main(process.argv.slice(2));
