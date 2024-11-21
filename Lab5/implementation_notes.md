# Implementation Notes

> 这份notes用于记录lab5实现过程中的各个模块设计的细节，以及其他报告、工程架构方面的说明，方便共同开发。

## Control Unit
这个模块还挺麻烦的，后面出bug大概率会在这个模块。

### 接口描述
```verilog
module CtrlUnit(
    input clk,
    input rst,

    input[31:0] inst,
    input valid_ID,
    
    input cmp_res_FU,

    // IF
    output reg_IF_en, branch_ctrl,

    // ID
    output reg_ID_en, reg_ID_flush,
    output[2:0] ImmSel,
    output ALU_en, MEM_en, MUL_en, DIV_en, JUMP_en,
    
    // FU
    output[3:0] JUMP_op,
    output[3:0] ALU_op,
    output ALUSrcA,
    output ALUSrcB,
    output MEM_we,
    
    // WB
    output reg[2:0] write_sel,
    output reg[4:0] rd_ctrl,
    output reg reg_write
);
```

### 重要线网及寄存器组含义解释
阅读这一部分的时候需要结合PPT第4到6页
#### `FU_status`
```verilog
    reg[5:0] FU_status;
```
1. `FU_status`的作用是记录当前每个FU是否被占用，这会在后面判断FU_structure_hazard，RAW, WAW都要用到
2. 需要注意的是`FU_status`的位数（6）实际上比FU的个数（5）多了一个，我理解这是为了方便从1开始索引FU。

#### `reservation_reg`

```verilog
    reg[2:0] reservation_reg [0:31]
```
1. `reservation_reg`是最关键的寄存器组，他记录的信息是接下来的32个周期内哪些寄存器需要被写回。
2. 比如`reservation_reg[3] = 3'd2`说明2号FU会在三个周期之后写回
3. 这个寄存器组会在每个周期动态更新。

#### `FU_write_to`

```verilog
    reg[4:0] FU_write_to [5:0];
```
1. `FU_write_to`记录的信息是各个FU写回的寄存器编号

#### `FU_writeback_en`
```verilog
    reg[5:0] FU_writeback_en;
```
1. `FU_writeback_en`记录的是当前这个FU能否被写回，当他被置为1的时候就会把当前FU中的结果写回到`rd`中。

#### `FU_delay_cycles`
```verilog
    reg[4:0] FU_delay_cycles [5:0];
```
1. `FU_delay_cycles`记录的是各个FU的初始latency，这是为了在register FU的时候把对应的FU写入到reservation_reg的对应位置。

#### `latency`
```verilog
    wire [4:0] latency [5:0];
```
1. 这个线网组表示的是各个FU当前还需要多少时间完成计算。代码中通过暴力判断`reservation_reg`中的数据是否和FU的编号一致，来获取各个FU当前周期的latency。

### 寄存器组维护逻辑



### 对于框架的建议
1. FU的delay cycles感觉设置个localparam会比较好维护

## RV32core
这个模块是CPU的数据通路

## FU_ALU
这个模块是框架已经实现的，感觉比较完善清晰了，这里就不再赘述大量细节（实际上FU_ALU的代码中也已经额外加入了一些注释，可以参考）。

### 接口描述
这里明确一下这个模块的各个接口
```verilog
module FU_ALU(
    input clk, EN, // 时钟和使能信号
    input[3:0] ALUControl, // 用于选取ALU操作（add, sub, ...)
    input[31:0] ALUA, ALUB, // 用于输入操作数
    output[31:0] res, // 输出计算结果
    output zero, overflow // 输出结果是否为零，以及是否有overflow
);
```


## FU_mul
这个模块的乘法实现已经在框架中完成（通过调用mul模块，可能是vivado内置的模块），我们需要实现的主要是手动实现latency功能。

这里实现latency的具体方式是，维护一个长度为`latency+1`（latency的大小需要根据`config.json`文件来设置）的state寄存器，在模块开始计算的时候就把他的初值设置为最高位为1，然后每一个周期都右移一位，直到移动了latency位，就把操作数读进来，传给mul模块进行计算。

然后最后输出结果`res`只有32位，但是`div`模块的结果是64位，所以人为slice一下。

### 接口描述
```verilog
module FU_mul(
    input clk, EN,
    input[31:0] A, B,
    output[31:0] res
);
```

> 实际上这里还没搞清楚这个模块没在运作的时候是怎么修改state寄存器的，因为假如state寄存器一直在移位，那么最坏的情况，指令刚刚运行到这个模块，刚好state处于全零的状态，然后就一个周期直接出结果，这样就没有模拟出latency的效果。这个问题可能需要在设计完其他模块之后才能解决。(难道是通过`enable`信号控制？)


## FU_div
这个模块和`FU_mul`模块设计思路基本一样，不再赘述。

### 接口描述
```verilog
module FU_div(
    input clk, EN,
    input[31:0] A, B,
    output[31:0] res
);
```

## FU_mem


### 接口描述
```verilog
module FU_mem(
    input clk, EN, mem_w, // mem_w为对mem的写信号
    input[2:0] bhw, // byte, half word, word, 具体需要根据外部模块判断哪个编码对应哪种长度
    input[31:0] rs1_data, rs2_data, imm, 
    output[31:0] mem_data // 输出
);
```

## FU_jump

### 接口描述
```verilog
module FU_jump(
	input clk, EN, JALR, // JALR信号为1，说明此时为JALR指令
	input[2:0] cmp_ctrl, // 应该是控制比较的类型，比如
	input[31:0] rs1_data, rs2_data, imm, PC,
	output[31:0] PC_jump, PC_wb, // 输出要跳转的PC地址、要写回的PC地址
	output cmp_res // 输出比较的结果
);
```