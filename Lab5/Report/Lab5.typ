//页脚
  #set page(footer: [
    计算机体系结构实验报告
    #h(1fr)
    #counter(page).display(
      "1/1",
      both: true,
    )
  ])
//缩进
  #import "@preview/indenta:0.0.3": fix-indent
  #show: fix-indent()
//注释
  #import "@preview/showybox:2.0.1": showybox 
  #let note(content) = align(left, text(11pt)[
    #showybox(
      title-style: (
        weight: 900,
        color: red.darken(40%),
        sep-thickness: 0pt,
        align: center
      ),
      frame: (
        title-color: red.lighten(80%),
        border-color: red.darken(40%),
        thickness: (left: 1pt),
        radius: 0pt
      ),
      title: "注意", 
      content
    )
  ])
//代码
  #import "@preview/codly:1.0.0": *
  #show: codly-init.with()
  #codly(languages: (
    Verilog: (name: "Verilog",  color: rgb("#CE412B")),
  ))
//标题
  #set heading(numbering: (..nums) => {
    if nums.pos().len()==1 {
    numbering("一、", nums.pos().at(0))
    }
    else {
    numbering("1.1", ..nums)
    }
  })
//字体
  #import "@preview/cuti:0.2.1": show-cn-fakebold
  #show: show-cn-fakebold
  #set text(13pt,font: ("Consolas", "STKaiti"))
  #set text(top-edge: 0.5em, bottom-edge: -0.3em)
//页面大小
  #set par(
    justify: true,
    leading: 1em,
    first-line-indent: 2em
  )

\
\
\
\
#align(center, image("./img/ZJUicon.jpg", width: 70%))
      

\
\
\
\
\
\
\


#align(center, text(30pt)[
  本科实验报告
])

#pagebreak()
#align(center, text(20pt)[
  浙江大学实验报告
])
#align(left, text(14pt)[
  #underline(extent:5pt,offset:3pt,[
   \ 
  ~~~~~课程名称：计算机体系结构 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~ \
  ~~~~~实验项目名称：多周期流水线CPU（乱序执行）~~~~~~~~~~~~~\
  ~~~~~学生姓名：韩墨 专业： 计算机科学与技术  学号：3220103978\
  ~~~~~同组学生姓名：   吴杭         指导老师： 姜晓红~~~~~~~~~~~~~~~~~~~~~~\
  ~~~~~实验地点： 曹西-301   实验日期：2024年11月17日~~~~~~~~])
])

#outline(depth:2, indent: true)

#pagebreak()
= 实验目的和要求





#pagebreak()
= 实验内容和原理
  == 多周期流水线CPU的结构
    - 此次实验中，我们将5阶段（IF/ID/EX/MEM/WB）流水线CPU改造为4阶段（IF/IS/EX/WB）多周期流水线CPU，EX阶段有ALU/jump/DIV/MUL/MEM5个FU(Function Unit) ，每个FU的执行周期各不相同，为了避免冒险，还要有额外的结构对指令和FU的状态进行记录
    - 以本次实验的多周期流水线CPU为例，其结构如下表所示：
    #align(center, text(9pt)[
      #set table(
        fill: (x, y) =>
          if x == 0 or y == 0 {
            gray.lighten(40%)
          },
        align: center,stroke: none
      )
      #show table.cell.where(x: 0): strong
      #table(
          columns: 2,
          [名称],[*描述*],
          table.hline(),
          table.cell(colspan:2, "多周期流水线CPU"),
          table.hline(),
          [reg[5:0] FU_status],[用于记录当前周期各个FU是否被占用，1为占用，0为空闲], 
          [reg[2:0] reservation_reg[0:31]],[用于记录正在流水线中即将写回寄存器的FU，一共可以追踪32个周期以后的写回情况，对应周期的位置记录要写回的FU编号，0代表该周期没有写回],
          [reg[4:0] FU_write_to[5:0]],[用于记录当前每个FU要写回的寄存器],
          [reg[5:0] FU_writeback_en],[用于记录记录FU写回的使能信号],
          [reg[4:0] FU_delay_cycles[5:0]],[保存每个FU的延迟周期数，不会修改],
        )
    ])
  == 冒险检测
    === WAW(Write-After-Write)
      - 描述：两个写操作，写入同一个寄存器先到的写操作先写，后到的写操作后写，不能够交换顺序，否则最终寄存器保存了第一次写的数据
      - 检测时间：IS阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 从FU_write_to寄存器中获取每个FU要写回的寄存器，与rd寄存器进行比较
        + 如果有写入同一个rd的FU，记为FU1，从reservation_reg中获取FU1剩余的执行周期，与当前指令所需周期比较
        + 如果FU1剩余周期小于当前指令所需周期，则没有WAW
        + 如果FU1剩余周期大于等于当前指令所需周期，那么继续执行的话当前指令会“超车”FU1，造成WAW
      #note(
        [reservation_reg[0:31]的最低位记录了当前要进行WB操作的FU，此时是可以继续执行的]
      )
      - 实现代码如下：
      首先通过暴力枚举比较的方式，计算出各种FU此时对应还需要多少周期才执行写回操作。
      ```v
assign latency[1] = reservation_reg[0] == 3'd1 ? 0 :
        reservation_reg[1] == 3'd1 ? 1 :
        reservation_reg[2] == 3'd1 ? 2 :
        reservation_reg[3] == 3'd1 ? 3 :
        ...
        reservation_reg[31] == 3'd1 ? 31 : 0;
assign latency[2] = ...
assign latency[3] = ...
assign latency[4] = ...
assign latency[5] = ...
```
然后再根据上面阐述的逻辑来判断这次的指令是否会出现WAW冒险。
```v
wire WAW = (FU_status[1] & rd != 5'b0 & rd_used & rd == FU_write_to[1] & FU_delay_cycles[use_FU] < latency[1])|
      (FU_status[2] & rd != 5'b0 & rd_used & rd == FU_write_to[2] & FU_delay_cycles[use_FU] < latency[2])|
      (FU_status[3] & rd != 5'b0 & rd_used & rd == FU_write_to[3] & FU_delay_cycles[use_FU] < latency[3])|
      (FU_status[4] & rd != 5'b0 & rd_used & rd == FU_write_to[4] & FU_delay_cycles[use_FU] < latency[4])|
      (FU_status[5] & rd != 5'b0 & rd_used & rd == FU_write_to[5] & FU_delay_cycles[use_FU] < latency[5]);
      ```
    === RAW(Read-After-Write)
      - 描述：读操作先于写操作到达，读操作读取了写操作前的数据，不能够交换顺序，否则读取结果会出错
      - 检测时间：IS阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 从FU_write_to寄存器中获取每个FU要写回的寄存器，与rs寄存器进行比较
        + 如果有相同的，那么存在RAW
        + 否则，不存在RAW
      - 代码实现如下：
      ```v
wire RAW_rs1 = 
          (FU_status[1] & rs1 != 5'b0 & rs1 == FU_write_to[1])| 
          (FU_status[2] & rs1 != 5'b0 & rs1 == FU_write_to[2])|
          (FU_status[3] & rs1 != 5'b0 & rs1 == FU_write_to[3])|
          (FU_status[4] & rs1 != 5'b0 & rs1 == FU_write_to[4])|
          (FU_status[5] & rs1 != 5'b0 & rs1 == FU_write_to[5]);
wire RAW_rs2 = 
          (FU_status[1] & rs2 != 5'b0 & rs2 == FU_write_to[1])|
          (FU_status[2] & rs2 != 5'b0 & rs2 == FU_write_to[2])|
          (FU_status[3] & rs2 != 5'b0 & rs2 == FU_write_to[3])|
          (FU_status[4] & rs2 != 5'b0 & rs2 == FU_write_to[4])|
          (FU_status[5] & rs2 != 5'b0 & rs2 == FU_write_to[5]);
      ```
    === WB Structure Hazard
      - 描述：在WB阶段，如果有两个写操作，会同时访问寄存器，造成冲突
      - 检测时间：IS阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 从FU_delay_cycles寄存器中获取对应FU的延迟周期数
        + 使用延迟作为index在reservation_reg中查找，如果对应位置有值，说明如果继续执行，最终会在同一周期有两个写操作，会有冲突
        + 如果没有值，说明没有冲突
      - 代码实现如下：
      ```v
      wire WB_structure_hazard = 
                      |reservation_reg[(FU_delay_cycles[use_FU])];
      ```
    === FU Structure Hazard
      - 描述：如果当前要使用的FU正在被占用，那么不能够立即使用，需要等待
      - 检测时间：IS（多周期流水线CPU）阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 检查FU_status寄存器，如果对应位置为1，说明该FU正在被占用，需要等待
        + 否则，可以使用该FU
        #note(
          [reservation_reg[0:31]的最低位记录了当前要进行WB操作的FU，此时对应FU已经解除占用了，是可以继续执行的]
        )
      - 代码实现如下：
      ```v
      wire FU_structure_hazard = 
                        FU_status[use_FU] & (reservation_reg[0]!=use_FU);
      ```
    === 为何没有包含WAR冒险
      - WAR(Write-After-Read)冒险是指写操作先于读操作到达，写操作在读操作前写入了数据，不能够交换顺序，否则最终结果会出错
      - 本实验的CPU结合不会发生WAR冒险，因为指令一旦发射，就直接把操作数读进来了，发生WAR的前提是后续指令在写的时候把前面的指令要读的寄存器给写了，但是我们本次实验中，前面的指令是会卡住后面的指令的，后面的指令不可能在前面指令还没读寄存器的值的时候，就直接发射并且写回了。与之相对的，scoreboard中的前一条指令（记为inst 1）可能在某些数据没准备好的时候就发射出去（不再影响到后续指令的发射），但是会一直等到数据准备好，才会读取寄存器的值。所以要是后续的指令执行的比inst 1之前的指令快很多，并且写回的还是inst 1需要的某个寄存器，那么就会出现WAR的问题。
  == ID阶段的等待机制
  本次实验的CPU结构，会根据当前ID阶段的指令是否出现Hazard来选择是否stall整条流水线。假如出现了FU_Hazard并且此时此时不出现跳转的行为，就会导致当前指令卡在ID阶段，后续的指令也无法继续发射。
  ```v
wire FU_hazard = 
        WAW|RAW_rs1|RAW_rs2|WB_structure_hazard|FU_structure_hazard;
assign reg_IF_en = ~FU_hazard | branch_ctrl;
assign reg_ID_en = reg_IF_en;
assign branch_ctrl = (B_in_FU & cmp_res_FU) |  J_in_FU;
  ```
  == 跳转逻辑
    === 跳转检测
    - 当遇到跳转指令的时候，会根据是branch指令还是jump指令来更新下一个周期中的B_in_FU和J_in_FU信号，然后同时根据FU_jump中得到的cmp_res_F来判断是否需要跳转。如果需要跳转，会根据FU_jump得到的PC_jump来判断跳转的位置。
    - 实现部分代码如下：
    ```v
  else if(valid_ID) begin  // register FU operation
    B_in_FU = B_valid;
    J_in_FU = JAL | JALR;
  end
  assign branch_ctrl = (B_in_FU & cmp_res_FU) |  J_in_FU;
    ```
    === Prediction-not-Taken
    本实验采用prediction-not-Taken的逻辑优化跳转指令的执行。也就是对于branch指令，假设这条指令不会真的跳转，在发射这条指令之后继续发射下一条指令来执行，而不进行stall。如果这条指令后续的确进行了taken，那么需要flush掉错误发射的指令。
    ```v
        always @ (posedge clk or posedge rst) begin
        if (rst) begin
            reg_ID_flush_next <= 0;
        end
        else begin
            reg_ID_flush_next <= branch_ctrl;
        end
    end
    if (use_FU == 3'b0 | reg_ID_flush_next | FU_hazard  | reg_ID_flush) begin
      for (i=0; i<31; i=i+1)
          reservation_reg[i] <= reservation_reg[i+1];
      reservation_reg[31] <= 32'b0;
      B_in_FU = 0;
      J_in_FU = 0;
    end
    assign reg_ID_flush = branch_ctrl;
    assign ALU_en = reg_IF_en & use_ALU & valid_ID & ~reg_ID_flush;
    assign MEM_en = reg_IF_en & use_MEM & valid_ID & ~reg_ID_flush;
    assign MUL_en = reg_IF_en & use_MUL & valid_ID & ~reg_ID_flush;
    assign DIV_en = reg_IF_en & use_DIV & valid_ID & ~reg_ID_flush;
    assign JUMP_en = reg_IF_en & use_JUMP & valid_ID & ~reg_ID_flush;
    ```


#pagebreak()


#pagebreak()
= 实验结果 
  == 本地仿真
  == 线上仿真
请给出本次实验仿真关键信号截图，并结合波形简要解释每种冒险的检测和解决，包括Prediction-not-Taken机制的效果。
#pagebreak()
= 讨论与心得
