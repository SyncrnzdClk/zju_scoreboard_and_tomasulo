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
  ~~~~~同组学生姓名：            指导老师： 姜晓红~~~~~~~~~~~~~~~~~~~~~~\
  ~~~~~实验地点： 曹西-301   实验日期：2024年11月17日~~~~~~~~])
])

#outline(depth:2, indent: true)

#pagebreak()
= 实验目的和要求

  #note([
    本实验的大部分代码已经给出，只需进行少量的代码补全以完整实现功能\ 20% bonus: 4-way set associative，放在报告最后一部分实现
  ])



#pagebreak()
= 实验内容和原理
  == ScoreBoard的结构
    - 此次实验中，我们将5阶段（IF/ID/EX/MEM/WB）流水线CPU改造为4阶段（IF/IS/EX/WB）多周期流水线CPU，EX阶段有ALU/jump/DIV/MUL/MEM5个FU(Function Unit) ，每个FU的执行周期各不相同，为了避免冒险，还要有额外的结构对指令和FU的状态进行记录
    - 以本次实验的ScoreBoard为例，其结构如下表所示：
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
          table.cell(colspan:2, "ScoreBoard"),
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
      - 检测时间：IS（ScoreBoard）阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 从FU_write_to寄存器中获取每个FU要写回的寄存器，与rd寄存器进行比较
        + 如果有写入同一个rd的FU，记为FU1，从reservation_reg中获取FU1剩余的执行周期，与当前指令所需周期比较
        + 如果FU1剩余周期小于当前指令所需周期，则没有WAW
        + 如果FU1剩余周期大于等于当前指令所需周期，那么继续执行的话当前指令会“超车”FU1，造成WAW
      #note(
        [reservation_reg[0:31]的最低位记录了当前要进行WB操作的FU，此时是可以继续执行的]
      )
    === RAW(Read-After-Write)
      - 描述：读操作先于写操作到达，读操作读取了写操作前的数据，不能够交换顺序，否则读取结果会出错
      - 检测时间：IS（ScoreBoard）阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 从FU_write_to寄存器中获取每个FU要写回的寄存器，与rs寄存器进行比较
        + 如果有相同的，那么存在RAW
        + 否则，不存在RAW
    === WB Structure Hazard
      - 描述：在WB阶段，如果有两个写操作，会同时访问寄存器，造成冲突
      - 检测时间：IS（ScoreBoard）阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 从FU_delay_cycles寄存器中获取对应FU的延迟周期数
        + 使用延迟作为index在reservation_reg中查找，如果对应位置有值，说明如果继续执行，最终会在同一周期有两个写操作，会有冲突
        + 如果没有值，说明没有冲突
    === FU Structure Hazard
      - 描述：如果当前要使用的FU正在被占用，那么不能够立即使用，需要等待
      - 检测时间：IS（ScoreBoard）阶段
      - 逻辑：
        + 首先获取输入的指令信息
        + 检查FU_status寄存器，如果对应位置为1，说明该FU正在被占用，需要等待
        + 否则，可以使用该FU
        #note(
          [reservation_reg[0:31]的最低位记录了当前要进行WB操作的FU，此时对应FU已经解除占用了，是可以继续执行的]
        )
    === 为何没有包含WAR冒险
      - WAR(Write-After-Read)冒险是指写操作先于读操作到达，写操作在读操作前写入了数据，不能够交换顺序，否则最终结果会出错
      - 由于寄存器正周期读负周期写，即使两个相邻的指令也不会发生先写后读
  == 跳转逻辑
    === 跳转检测
    === Prediction-not-Taken

#pagebreak()
= 实验过程

#pagebreak()
= 实验结果 
  == 本地仿真
  == 线上仿真
请给出本次实验仿真关键信号截图，并结合波形简要解释每种冒险的检测和解决，包括Prediction-not-Taken机制的效果。
#pagebreak()
= 讨论与心得
