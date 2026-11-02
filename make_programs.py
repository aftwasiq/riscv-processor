#!/usr/bin/env python3
"""Encode the two RV32I test programs as little-endian binary files."""
from pathlib import Path
import struct

PROGRAMS = Path(__file__).resolve().parent / "programs"
PROGRAMS.mkdir(exist_ok=True)


def r_type(funct7, rs2, rs1, funct3, rd):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x33


def i_type(imm, rs1, funct3, rd, opcode=0x13):
    assert -2048 <= imm <= 2047
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def s_type(imm, rs2, rs1, funct3=2):
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 31) << 7) | 0x23


def b_type(offset, rs2, rs1, funct3):
    assert offset % 2 == 0 and -4096 <= offset <= 4094
    imm = offset & 0x1FFF
    return (
        (((imm >> 12) & 1) << 31)
        | (((imm >> 5) & 63) << 25)
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | (((imm >> 1) & 15) << 8)
        | (((imm >> 11) & 1) << 7)
        | 0x63
    )


arithmetic = [
    i_type(5, 0, 0, 1),          # ADDI x1, x0, 5
    i_type(7, 0, 0, 2),          # ADDI x2, x0, 7
    r_type(0, 2, 1, 0, 3),      # ADD  x3, x1, x2
    r_type(0x20, 1, 3, 0, 4),   # SUB  x4, x3, x1
    r_type(0, 2, 1, 7, 5),      # AND  x5, x1, x2
    r_type(0, 2, 1, 6, 6),      # OR   x6, x1, x2
    r_type(0, 2, 1, 4, 7),      # XOR  x7, x1, x2
    r_type(0, 1, 1, 1, 8),      # SLL  x8, x1, x1
    r_type(0, 1, 8, 5, 9),      # SRL  x9, x8, x1
    i_type(6, 3, 7, 10),        # ANDI x10, x3, 6
    i_type(8, 1, 6, 11),        # ORI  x11, x1, 8
    i_type(3, 1, 4, 12),        # XORI x12, x1, 3
    0x00100073,                # EBREAK
]

memory_branch = [
    i_type(256, 0, 0, 1),       # ADDI x1, x0, 256
    i_type(42, 0, 0, 2),        # ADDI x2, x0, 42
    s_type(0, 2, 1),            # SW   x2, 0(x1)
    i_type(0, 1, 2, 3, 0x03),  # LW   x3, 0(x1)
    b_type(8, 3, 2, 0),         # BEQ  x2, x3, +8
    i_type(99, 0, 0, 4),        # skipped
    i_type(1, 0, 0, 4),         # ADDI x4, x0, 1
    b_type(8, 2, 4, 1),         # BNE  x4, x2, +8
    i_type(99, 0, 0, 5),        # skipped
    i_type(2, 0, 0, 5),         # ADDI x5, x0, 2
    i_type(-1, 0, 0, 6),        # ADDI x6, x0, -1
    0x00100073,                # EBREAK
]

for name, instructions in (("arithmetic", arithmetic), ("memory_branch", memory_branch)):
    data = b"".join(struct.pack("<I", word) for word in instructions)
    output = PROGRAMS / f"{name}.bin"
    output.write_bytes(data)
    print(f"{output}: {len(instructions)} instructions, {len(data)} bytes")
