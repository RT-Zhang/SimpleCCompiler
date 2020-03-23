# 简易C编译器
## 实现的C特性
* 变量定义（支持int、char、bool）
* 变量赋值
* if 语句
* while 语句
* for 语句
* 复合语句
* 输入输出（借助MASM32宏）
## 项目工具
+ Parser Generator
+ MASM32
## 步骤
### 词法分析
#### Lex 规则 
编写正则表达式，利用 Lex 工具实现词法分析器，通过正规定义识别所有单词，将源程序转化为单词流，获得每个单词的词素内容、单词类别和属性。   
#### 符号表
使用 unordered_map 实现符号表。  
保存出现的标识符，并对每一个标识符给予一个指针位置（用数字表示），对于符号表的维护更新，当出现一个标识符后，遍历符号表的符号表项，若已存在，则输出对应的指针位置，若不存在，则表示该标识符第一次出现，将其加入符号表中。  
根据需求，key 为 string 类型，value 为 int 类型
### 语法分析
#### Yacc
设计上下文无关文法进行描述，借助 Yacc 工具实现，构造一棵语法树。  
#### 语法树
树节点分为语句 Stmt 类型，表达式 Exp 类型，变量声明 Decl 类型三种大类型。节点类型使用 enum，以便节点类型使用 int 类型表示。  
对于树节点结构，主要包含节点号，孩子节点，节点类型，具体类型（比如 Stmt 下属的 If 语句节点）。此外，如果该节点为标识符、符号或者数字应当进行保存，三者不会同时存在，所以使用 union 结构进行保存。
#### 辅助函数
完成节点的创建，将对应元素的数值进行填充，并根据上下文无关文法将多个节点进行连接，最终形成一颗完整的语法树。  
辅助函数如下：
* 节点创建
    * Stmt 节点创建
    * Exp 节点创建
    * Decl 节点创建
* 输出整个语法树（采用递归的方式）
* 打印某具体的节点
### 类型检查
基于上面构造的语法树实现，同样采用递归来检查。  
主要为根据节点类型以及其子类型确定了该节点的具体操作。
* 双目运算两侧类型相同
* 变量使用前要赋值
* If、While、For 语句的判断部分为 bool 类型
### x86 代码生成
变量定义、输入、输出借助部分 MASM32 的宏特性。  
主要包括实现关于数据段（.data）以及代码段（.code）这两个汇编代码的主要部分，此外，还需要一些辅助函数（如临时变量分配函数）并且需要完善节点元素（如为了实现跳转语句加入的 label）。
#### 标号生产
针对语句和表达式，实现汇编代码的跳转。采用递归的方法实现。  
主要包括：开始标号、下一条语句标号、真值出口标号、假值出口标号
#### 临时变量分配
计算需要申请的临时变量的数量，应尽量少申请，够用即可。一个表达式节点每有一个孩子是表达式节点，就可以少申请一个。
#### 目标代码生成
采用递归的方法实现。  
先生成汇编代码头部（如引用 MASM32 宏），之后将所有 C 语言中所有与声明相关的语句转化为数据段的相关内容，之后再将代码段的相关内容进行输出，最后调用退出程序函数 ExitProcess 以及结束符 end，汇编程序完成。  
int 变量声明为 DWORD 双字，char 变量声明为 BYTE 单字节。然后声明临时变量。  
通过区分节点类型进行汇编语言的构建。
## 项目测试
使用 Parser Generator 将 Lex 和 Yacc 源文件编译为 C++ 的头文件和源文件，得到 C 编译程序。  
像编译程序输入一段代码，执行后生成 x86 的 asm 文件。  
借助 MASM32 运行汇编代码，测试结果的正确性。