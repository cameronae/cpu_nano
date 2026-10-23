#include "VBranchPredictor.h"
#include "verilated.h"
#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <random>
#include <stdexcept>
#ifndef PREDICTOR_MODE
#define PREDICTOR_MODE 1
#endif

int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    VBranchPredictor dut;
    std::array<bool,64> valid{}, conditional{};
    std::array<uint32_t,64> tags{}, targets{};
    std::array<unsigned,64> counters{};
    counters.fill(1);
    unsigned history=0;
    std::mt19937 gen(20);
    try {
        auto check=[&]() {
            unsigned slot=(dut.fetch_pc>>2)&63;
            unsigned index=slot^(PREDICTOR_MODE==2?history:0);
            bool hit=valid[slot] && tags[slot]==(dut.fetch_pc>>8);
            uint32_t npc=hit&&(!conditional[slot]||counters[index]>=2)?targets[slot]:dut.fetch_pc+4;
            if(dut.prediction_index!=index || dut.predicted_next_pc!=npc)
                throw std::runtime_error("lookup/index mismatch");
        };
        auto cycle=[&](bool reset) {
            dut.reset=reset; dut.clk=0; dut.eval();
            if(!reset) check();
            dut.clk=1; dut.eval();
            if(reset) { valid.fill(false); counters.fill(1); history=0; }
            else if(dut.update) {
                unsigned slot=(dut.resolved_pc>>2)&63, index=dut.resolved_index;
                valid[slot]=true; tags[slot]=dut.resolved_pc>>8;
                targets[slot]=dut.resolved_target&~3u; conditional[slot]=dut.resolved_conditional;
                if(dut.resolved_conditional) {
                    int n=int(counters[index])+(dut.resolved_taken?1:-1);
                    counters[index]=unsigned(std::max(0,std::min(3,n)));
                    history=((history<<1)|dut.resolved_taken)&63;
                }
            }
            check();
        };
        dut.fetch_pc=0; dut.update=0; cycle(true);
        // Exercise both saturation endpoints, both direction transitions, and
        // unconditional hits independent of the direction table.
        for(unsigned n=0;n<24;n++) {
            dut.update=1; dut.resolved_pc=0; dut.resolved_target=128;
            dut.resolved_index=0; dut.resolved_conditional=n<20;
            dut.resolved_taken=n<10; cycle(false);
        }
        // Aliasing targets must miss on tag mismatch. Counter aliasing is legal.
        for(unsigned n=0;n<10000;n++) {
            dut.fetch_pc=(gen()%512)*4;
            dut.update=gen()%3!=0; dut.resolved_pc=(gen()%512)*4;
            dut.resolved_target=(gen()%1024)*4;
            dut.resolved_conditional=gen()%2; dut.resolved_taken=gen()%2;
            dut.resolved_index=gen()%64;
            cycle(n%997==0);
        }
        std::cout<<"PASS predictor mode "<<PREDICTOR_MODE<<" saturation, tags, aliasing, history, reset\n";
    } catch(const std::exception& e) { std::cerr<<"FAIL predictor "<<e.what()<<"\n"; return 1; }
}
