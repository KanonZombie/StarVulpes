// Offline register/event extractor. Uses the unmodified local Snes9x/bapu
// S-SMP interpreter, not an SPC interpreter in the Mega Drive cartridge.
// See THIRD_PARTY.md and the Snes9x reference's COPYING for its licence.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <map>
#include <vector>
#include <algorithm>
#include <stdexcept>
#include <string>
using uint8 = uint8_t; using uint16 = uint16_t; using uint64 = uint64_t;
using int8 = int8_t; using int16 = int16_t; using int64 = int64_t;
#define alwaysinline inline
#define debugvirtual
#define SMP_CPP
namespace SNES {
struct Processor { int64 clock = 0; };
#include <smp.hpp>
SMP smp;
struct Host {
    uint8 in[4] = {};
    unsigned port_read(unsigned address) { return in[address & 3]; }
    void port_write(unsigned address, unsigned data) { in[address & 3] = data; }
} cpu;
struct TraceDSP {
    int64 clock = 0;
    uint8 regs[128] = {};
    std::ofstream output;
    bool recording = false;
    uint64 origin = 0;
    unsigned read(unsigned address) {
        // Control-register readback (EDL/EON, etc.) is stored exactly.
        // ENVX, OUTX and ENDX would require an actual DSP, so fail closed.
        unsigned reg = address & 127;
        if ((reg & 15) == 8 || (reg & 15) == 9 || reg == 0x7c)
            throw std::runtime_error("DSP-dependent read " + std::to_string(address) + " PC " + std::to_string(smp.regs.pc));
        return regs[address & 127];
    }
    void write(unsigned address, unsigned value) {
        bool changed = regs[address] != value;
        regs[address] = value;
        if (!recording || (!changed && address != 0x4c && address != 0x5c)) return;
        uint32_t time = uint32_t(smp.clock - origin);
        uint8 record[30] = {};
        for (int i = 0; i < 4; i++) record[i] = time >> (i * 8);
        record[4] = address; record[5] = value;
        for (int i = 0; i < 8; i++) {
            record[6 + i] = smp.apuram[0x361 + i * 2];
            record[14 + i] = smp.apuram[0x360 + i * 2];
            record[22 + i] = smp.apuram[0x211 + i * 2];
        }
        output.write(reinterpret_cast<char*>(record), sizeof(record));
    }
} dsp;
#include <algorithms.cpp>
#include <core.cpp>
#include <memory.cpp>
#include <timing.cpp>
// The conversion starts at the uploaded sound driver. The SNES IPL is
// unnecessary; stop if a driver attempts to execute it.
const uint8 SMP::iplrom[64] = {};
SMP::SMP() { apuram = new uint8[65536](); }
SMP::~SMP() { delete[] apuram; }
}

int main(int argc, char** argv) {
    using namespace SNES;
    try {
        if (argc != 6) throw std::runtime_error("spc-trace ram.bin trace.bin port command max-seconds");
        std::ifstream input(argv[1], std::ios::binary);
        input.read(reinterpret_cast<char*>(smp.apuram), 65536);
        if (input.gcount() != 65536) throw std::runtime_error("Expected 65536-byte ARAM image");
        smp.regs = {}; smp.status = {};
        smp.regs.pc = 0x400; smp.regs.sp = 0xef; smp.regs.p = 2;
        smp.timer0 = {}; smp.timer1 = {}; smp.timer2 = {};
        int port = std::stoi(argv[3]), command = std::stoi(argv[4]);
        if (port < 0 || port > 3 || command < 1 || command > 255) throw std::runtime_error("Bad request");
        dsp.output.open(argv[2], std::ios::binary);
        if (!dsp.output) throw std::runtime_error("Cannot create trace");
        // Recognise the original adset routine and the CALL adset/BNE ks40
        // instruction in the original driver. This is a semantic boundary,
        // not a guessed frame counter or a duration from soundtrack tags.
        // Offsets in ARAM after loading the verified USA SBNs.
        constexpr unsigned adset = 0x0758, playlist = 0x07ef;
        if (smp.apuram[playlist] != 0x3f || smp.apuram[playlist+1] != (adset & 255)
                || smp.apuram[playlist+2] != adset >> 8 || smp.apuram[playlist+3] != 0xd0)
            throw std::runtime_error("Original playlist interpreter not found");
        uint64 start = 256000, limit = start + uint64(std::stod(argv[5]) * 1024000);
        int64 loop_start = -1, loop_end = -1, song_end = -1;
        bool sent = false, echoed = false, sounding = false;
        std::map<unsigned, uint64> positions;
        std::map<unsigned, uint64> first_position;
        std::vector<std::pair<uint64, unsigned>> order;
        std::vector<std::pair<uint64, unsigned>> tempos;
        unsigned last_tempo = 256;
        while (uint64(smp.clock) < limit) {
            if (!sent && uint64(smp.clock) >= start) {
                start = smp.clock;
                cpu.in[port] = command;
                dsp.recording = true; dsp.origin = start;
                // Complete initial DSP state precedes the event stream.
                for (unsigned i = 0; i < 128; i++) {
                    unsigned value = dsp.regs[i]; dsp.regs[i] ^= 255; dsp.write(i, value);
                }
                sent = true;
            }
            if (sent && !echoed && smp.apuram[0xf4 + port] == command) {
                cpu.in[port] = 0; echoed = true;
            }
            if (sent && smp.apuram[0x53] != last_tempo) {
                last_tempo = smp.apuram[0x53];
                tempos.emplace_back(smp.clock - start, last_tempo);
            }
            if (sent && port == 0 && smp.regs.pc == playlist) {
                unsigned pointer = smp.apuram[0x40] | smp.apuram[0x41] << 8;
                unsigned key = pointer | smp.apuram[0x42] << 16;
                uint64 time = smp.clock - start;
                order.emplace_back(time, pointer);
                unsigned word = smp.apuram[pointer] | smp.apuram[(pointer + 1) & 65535] << 8;
                unsigned target = smp.apuram[(pointer + 2) & 65535] | smp.apuram[(pointer + 3) & 65535] << 8;
                // ks20: negative 8-bit repeat counts loop forever. Detect
                // that branch at its original boundary, before the counter
                // changes from zero to $80..$ff on the next traversal.
                if (word >= 0x80 && word < 0x100 && target < pointer && first_position.count(target)) {
                    loop_start = first_position[target]; loop_end = time;
                    break;
                }
                if (positions.count(key) && time > positions[key] + 1024000) {
                    loop_start = positions[key]; loop_end = time;
                    break;
                }
                positions.emplace(key, time);
                first_position.emplace(pointer, time);
            }
            if (sent && echoed) {
                unsigned status = smp.apuram[port == 0 ? 4 : 7];
                if (status) sounding = true;
                if (sounding && !status && song_end < 0) song_end = smp.clock - start;
                if (song_end >= 0 && smp.clock - start > uint64(song_end) + 1024000) break;
            }
            smp.op_step();
            if (smp.status.iplrom_enable && smp.regs.pc >= 0xffc0)
                throw std::runtime_error("Unexpected SPC IPL execution");
        }
        std::cout << "{\"cycles\":" << smp.clock - start << ",\"echoed\":" << (echoed ? "true" : "false")
                  << ",\"loop_start\":" << loop_start << ",\"loop_end\":" << loop_end
                  << ",\"song_end\":" << song_end << ",\"playlist_pc\":" << playlist << ",\"orders\":[";
        for (size_t i = 0; i < order.size(); i++) {
            if (i) std::cout << ',';
            std::cout << '[' << order[i].first << ',' << order[i].second << ']';
        }
        std::cout << "],\"tempos\":[";
        for (size_t i = 0; i < tempos.size(); i++) {
            if (i) std::cout << ',';
            std::cout << '[' << tempos[i].first << ',' << tempos[i].second << ']';
        }
        std::cout << "]}\n";
    } catch (const std::exception& e) {
        std::cerr << e.what() << '\n'; return 1;
    }
}
