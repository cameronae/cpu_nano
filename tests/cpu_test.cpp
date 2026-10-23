#include "VDatapath.h"
#include "verilated.h"
#include <array>
#include <cstdint>
#include <iostream>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>
#include <sstream>

static constexpr unsigned WORDS = 4096;
static constexpr uint32_t STOP = 0xffffffff;
static uint32_t R(unsigned rs,unsigned rt,unsigned rd,unsigned sh,unsigned fn) {
    return (rs<<21)|(rt<<16)|(rd<<11)|(sh<<6)|fn;
}
static uint32_t I(unsigned op,unsigned rs,unsigned rt,int imm) {
    return (op<<26)|(rs<<21)|(rt<<16)|(uint32_t(imm)&65535);
}
static uint32_t J(unsigned op,unsigned index) { return (op<<26)|index; }
static std::string hex(uint32_t v) { std::ostringstream s; s<<std::hex<<v; return s.str(); }
static void require(bool b,const std::string& msg) { if(!b) throw std::runtime_error(msg); }

struct Reference {
    std::array<uint32_t,32> r{};
    std::array<uint32_t,WORDS> mem{};
    uint32_t pc=0;
    std::array<unsigned,64> ops{}, funcs{};
    struct Result { bool write=false; unsigned dest=0; uint32_t data=0; unsigned fault=0; };
    Result step(uint32_t ins, bool ifault) {
        Result out;
        unsigned op=ins>>26, rs=(ins>>21)&31, rt=(ins>>16)&31;
        unsigned rd=(ins>>11)&31, sh=(ins>>6)&31, fn=ins&63;
        uint32_t a=r[rs], b=r[rt], next=pc+4;
        int32_t simm=int16_t(ins&65535);
        uint32_t uimm=ins&65535;
        bool known=true, load=false, store=false, uns=false, taken=false, control=false;
        unsigned size=4;
        uint32_t addr=0, result=0;
        unsigned dest=rt;
        auto wr=[&](uint32_t value) { out.write=true; result=value; };
        if(ifault) out.fault=5;
        else if(pc&3) out.fault=2;
        else {
            ops[op]++;
            switch(op) {
            case 0:
                funcs[fn]++; dest=rd;
                switch(fn) {
                case 0x20: case 0x21: wr(a+b); break;
                case 0x22: case 0x23: wr(a-b); break;
                case 0x24: wr(a&b); break; case 0x25: wr(a|b); break;
                case 0x26: wr(a^b); break; case 0x27: wr(~(a|b)); break;
                case 0x2a: wr(int32_t(a)<int32_t(b)); break;
                case 0x2b: wr(a<b); break;
                case 0: wr(b<<sh); break; case 2: wr(b>>sh); break;
                case 3: wr(uint32_t(int32_t(b)>>sh)); break;
                case 4: wr(b<<(a&31)); break; case 6: wr(b>>(a&31)); break;
                case 7: wr(uint32_t(int32_t(b)>>(a&31))); break;
                case 8: control=true; taken=true; next=a; break;
                case 9: control=true; taken=true; next=a; wr(pc+4); break;
                default: known=false;
                }
                break;
            case 8: case 9: wr(a+uint32_t(simm)); break;
            case 0xa: wr(int32_t(a)<simm); break;
            case 0xb: wr(a<uint32_t(simm)); break;
            case 0xc: wr(a&uimm); break; case 0xd: wr(a|uimm); break;
            case 0xe: wr(a^uimm); break; case 0xf: wr(uimm<<16); break;
            case 0x20: load=true; size=1; break;
            case 0x21: load=true; size=2; break;
            case 0x23: load=true; break;
            case 0x24: load=true; size=1; uns=true; break;
            case 0x25: load=true; size=2; uns=true; break;
            case 0x28: store=true; size=1; break;
            case 0x29: store=true; size=2; break;
            case 0x2b: store=true; break;
            case 4: control=true; taken=a==b; break;
            case 5: control=true; taken=a!=b; break;
            case 6: control=true; taken=int32_t(a)<=0; known=rt==0; break;
            case 7: control=true; taken=int32_t(a)>0; known=rt==0; break;
            case 1: control=true;
                if(rt==0) taken=int32_t(a)<0;
                else if(rt==1) taken=int32_t(a)>=0;
                else known=false;
                break;
            case 2: case 3:
                control=true; taken=true; next=((pc+4)&0xf0000000)|((ins&0x3ffffff)<<2);
                if(op==3) { dest=31; wr(pc+4); }
                break;
            default: known=false;
            }
            if(control && op!=0 && op!=2 && op!=3 && taken)
                next=pc+4+uint32_t(simm)*4;
            if(!known) out.fault=1;
            else if(control && taken && (next&3)) out.fault=2;
            if(load||store) {
                addr=a+uint32_t(simm);
                if(addr%size) out.fault=store?4:3;
                else if(addr/4>=WORDS) out.fault=store?7:6;
                if(!out.fault) {
                    unsigned offset=(addr&3)*8;
                    uint32_t mask=size==4?0xffffffffu:((1u<<(size*8))-1);
                    if(store) mem[addr/4]=(mem[addr/4]&~(mask<<offset))|((b&mask)<<offset);
                    else {
                        uint32_t v=(mem[addr/4]>>offset)&mask;
                        if(!uns && size==1) v=uint32_t(int32_t(int8_t(v)));
                        if(!uns && size==2) v=uint32_t(int32_t(int16_t(v)));
                        wr(v);
                    }
                }
            }
        }
        out.dest=dest; out.data=result;
        if(out.fault || dest==0) out.write=false;
        if(out.write) r[dest]=result;
        r[0]=0;
        pc=next;
        return out;
    }
};

struct Simulation {
    VDatapath dut;
    Reference ref;
    std::array<uint32_t,WORDS> rom{}, ram{};
    unsigned cycles=0, retired=0, stalls=0, redirects=0;
    bool saw_fault=false;
    std::string name;
    Simulation(const std::string& n,const std::vector<uint32_t>& program):name(n) {
        rom.fill(STOP);
        require(program.size()<WORDS,"program too big");
        std::copy(program.begin(),program.end(),rom.begin());
        for(unsigned i=0;i<WORDS;i++) ram[i]=ref.mem[i]=0x81807f00u^(i*0x10204081u);
        dut.instruction_data=0; dut.instruction_fault=0;
        dut.data_read_data=0; dut.data_fault=0; dut.reset=1;
        tick(false); tick(false); dut.reset=0;
    }
    void tick(bool check=true) {
        dut.clk=0; dut.eval();
        dut.data_fault=dut.data_enable && dut.data_address/4>=WORDS;
        dut.eval();
        if(check && dut.retire_valid) {
            require(!saw_fault,name+": retired after fault");
            require(dut.retire_pc==ref.pc,name+": PC got "+hex(dut.retire_pc)+" expected "+hex(ref.pc));
            uint32_t instruction=ref.pc/4<WORDS?rom[ref.pc/4]:0;
            require(dut.retire_instruction==instruction,name+": instruction mismatch");
            auto expected=ref.step(instruction,ref.pc/4>=WORDS);
            require(dut.retire_fault==expected.fault,name+": fault mismatch at "+hex(dut.retire_pc));
            require(bool(dut.retire_write)==expected.write,name+": write-enable mismatch at "+hex(dut.retire_pc));
            if(expected.write) {
                require(dut.retire_destination==expected.dest,name+": destination mismatch");
                require(dut.retire_data==expected.data,name+": result at "+hex(dut.retire_pc)+
                    " got "+hex(dut.retire_data)+" expected "+hex(expected.data));
            }
            if(expected.fault) saw_fault=true;
            retired++;
        }
        bool if_en=dut.instruction_enable;
        uint32_t ia=dut.instruction_address;
        bool mem_en=dut.data_enable && !dut.data_fault;
        uint32_t addr=dut.data_address, wd=dut.data_write_data;
        unsigned strobes=dut.data_write_strobes;
        uint32_t read_value=mem_en?ram[addr/4]:dut.data_read_data;
        stalls+=dut.load_stall && !dut.reset;
        redirects+=dut.redirect_event && !dut.reset;
        dut.clk=1; dut.eval();
        if(if_en) {
            dut.instruction_data=ia/4<WORDS?rom[ia/4]:0;
            dut.instruction_fault=ia/4>=WORDS;
        }
        if(mem_en) {
            for(unsigned lane=0;lane<4;lane++) if(strobes&(1<<lane))
                ram[addr/4]=(ram[addr/4]&~(0xffu<<(lane*8)))|(wd&(0xffu<<(lane*8)));
            dut.data_read_data=read_value;
        }
        dut.eval(); cycles++;
    }
    void run(unsigned limit=30000) {
        while(!dut.halted && cycles<limit) tick();
        require(dut.halted && saw_fault,name+": timeout/no fault retirement");
        for(unsigned i=0;i<WORDS;i++) require(ram[i]==ref.mem[i],name+": memory mismatch word "+std::to_string(i));
        for(unsigned i=0;i<8;i++) tick();
        std::cout<<"PASS "<<name<<" cycles="<<cycles<<" retired="<<retired
                 <<" load-stalls="<<stalls<<" redirects="<<redirects<<"\n";
    }
};

int main(int argc,char** argv) {
    Verilated::commandArgs(argc,argv);
    try {
        // All currently supported operations, boundary values and RAW distances.
        std::vector<uint32_t> p={I(9,0,1,-1),I(0xf,0,2,0x8000),I(0xd,2,2,1),I(9,0,3,31)};
        for(unsigned fn: {0x20u,0x21u,0x22u,0x23u,0x24u,0x25u,0x26u,0x27u,0x2au,0x2bu}) {
            p.push_back(R(1,2,4,0,fn)); p.push_back(R(4,1,5,0,0x21));
        }
        for(unsigned fn: {0u,2u,3u,4u,6u,7u}) {
            p.push_back(R(fn&4?3:0,2,6,31,fn)); p.push_back(R(6,6,7,0,0x26));
        }
        for(unsigned op:{8u,9u,0xau,0xbu,0xcu,0xdu,0xeu,0xfu})
            for(int imm:{0,1,0x7fff,0x8000,0xffff}) p.push_back(I(op,2,8,imm));
        p.insert(p.end(),{I(9,0,0,99),R(0,0,9,0,0x21),I(9,0,1,0),I(9,0,2,-128)});
        for(unsigned offset=0;offset<4;offset++) {
            p.push_back(I(0x28,1,2,offset)); p.push_back(I(0x20,1,3,offset));
            p.push_back(I(0x24,1,4,offset)); p.push_back(R(3,4,5,0,0x21));
        }
        for(unsigned offset:{0u,2u}) {
            p.push_back(I(0x29,1,2,offset)); p.push_back(I(0x21,1,3,offset));
            p.push_back(I(0x25,1,4,offset)); p.push_back(I(0x2b,1,4,8));
        }
        p.insert(p.end(),{I(0x23,1,5,8),R(5,5,6,0,0x21),I(0x23,1,7,8),
            I(0x2b,1,7,12),I(0x23,1,0,0),R(0,6,8,0,0x21),STOP});
        Simulation ops("integer-and-memory",p); ops.run();
        // Branches exercise both outcomes, taken-path squashing, link/return,
        // load->branch and load->register-jump, and a backward loop.
        p={I(9,0,1,3),I(9,0,2,-1),I(9,0,3,1)};
        auto branch_pair=[&](unsigned op,unsigned rs,unsigned rt) {
            p.push_back(I(op,rs,rt,2)); p.push_back(I(0x2b,0,2,100));
            p.push_back(I(9,0,10,123)); p.push_back(I(9,0,11,7));
        };
        branch_pair(4,1,1); branch_pair(4,1,2);
        branch_pair(5,1,2); branch_pair(5,1,1);
        branch_pair(6,2,0); branch_pair(6,3,0);
        branch_pair(7,3,0); branch_pair(7,2,0);
        branch_pair(1,2,0); branch_pair(1,3,0);
        branch_pair(1,3,1); branch_pair(1,2,1);
        unsigned loop=p.size(); p.push_back(I(9,1,1,-1));
        p.push_back(I(5,1,0,int(loop)-int(p.size())-1));
        unsigned call=p.size(); p.push_back(J(3,call+4));
        p.push_back(J(2,call+7)); p.push_back(I(0x2b,0,2,104)); p.push_back(0);
        p.push_back(R(31,0,12,0,0x21)); p.push_back(R(31,0,0,0,8));
        p.push_back(I(0x2b,0,2,108));
        unsigned jr=p.size();
        p.push_back(I(9,0,13,(jr+5)*4)); p.push_back(I(0x2b,0,13,112));
        p.push_back(I(0x23,0,14,112)); p.push_back(R(14,0,15,0,9));
        p.push_back(I(0x2b,0,2,116));
        p.push_back(I(0x23,0,16,112)); p.push_back(I(4,16,13,1));
        p.push_back(I(0x2b,0,2,120)); p.push_back(STOP);
        Simulation branches("control-flow",p); branches.run();
        // Faults must drain older work and suppress younger stores.
        for(auto instruction: {I(0x23,0,1,1),I(0x29,0,1,1),I(0x23,0,1,WORDS*4),
                             I(0x2b,0,1,WORDS*4),uint32_t(0xfc000000)}) {
            Simulation f("fault-"+hex(instruction),{I(9,0,2,17),instruction,I(0x2b,0,2,128),STOP}); f.run();
        }
        Simulation misjump("misaligned-jr",{I(9,0,1,3),R(1,0,0,0,8),I(0x2b,0,1,132)}); misjump.run();
        Simulation ifault("instruction-access-fault",{J(2,WORDS),I(0x2b,0,1,136)}); ifault.run();
        // Seeded random instruction streams use a completely separate interpreter.
        for(unsigned seed=1;seed<=8;seed++) {
            std::mt19937 gen(seed); p.clear();
            for(unsigned r=1;r<32;r++) p.push_back(I(0xd,0,r,int(gen()&65535)));
            const unsigned funcs[]={0,2,3,4,6,7,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x2a,0x2b};
            const unsigned immops[]={8,9,0xa,0xb,0xc,0xd,0xe,0xf};
            const unsigned memops[]={0x20,0x21,0x23,0x24,0x25,0x28,0x29,0x2b};
            for(unsigned n=0;n<1500;n++) {
                unsigned kind=gen()%4, rs=gen()%32, rt=gen()%32, rd=gen()%32;
                if(kind==0) p.push_back(R(rs,rt,rd,gen()%32,funcs[gen()%16]));
                else if(kind==1) p.push_back(I(immops[gen()%8],rs,rt,int(gen()&65535)));
                else if(kind==2) {
                    unsigned op=memops[gen()%8], addr=gen()%1024;
                    if((op&3)==1) addr&=~1u;
                    if((op&3)==3) addr&=~3u;
                    p.push_back(I(op,0,rt,int(addr)));
                } else {
                    // Short forward branches create wrong paths without infinite loops.
                    p.push_back(I(gen()%2?4:5,rs,rt,int(gen()%4)));
                }
            }
            p.push_back(STOP);
            Simulation random("random-seed-"+std::to_string(seed),p); random.run();
        }
        // Reset with instructions in flight: no pre-reset retirement or writes.
        Simulation reset("reset-in-flight",{I(9,0,1,4),I(0x2b,0,1,0),STOP});
        reset.tick(); reset.tick(); reset.tick(); reset.dut.reset=1;
        reset.tick(false); reset.tick(false);
        require(!reset.dut.retire_valid && !reset.dut.data_enable,"reset side effects");
        reset.ref=Reference{}; reset.ref.mem=reset.ram; reset.dut.reset=0;
        reset.run();
        std::cout<<"All CPU tests passed\n";
    } catch(const std::exception& e) { std::cerr<<"FAIL "<<e.what()<<"\n"; return 1; }
}
