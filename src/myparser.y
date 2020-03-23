%{
#include "mylexer.h"
#include <cstdlib>
#include <map>
#include <string>
#include <cstdio>
#include <Windows.h>
#include <iostream>
#include <fstream>
using namespace std;

map<string, int> mymap;

int idcount = 0;
enum { StmtK, ExpK, DeclK };
enum { IfK, WhileK, AssignK, ForK, CompK, InputK, PrintK, JumpK, SemiK };
enum { OpK, ConstK, IdK, TypeK, CK };
enum { VarK };  //变量声明
enum { Void, Integer, Char, Boolean };

#define MAXCHILDREN 4//最多孩子数
int line = 0;
int Num = 0;//给ShowNode行数计数
int err = 0;
ofstream out("output.asm");

struct Label {
	char* true_label;
	char* false_label;
	char* begin_label;
	char* next_label;
};//标签类

int temp_var_seq = 0;//所需要的临时变量赋值数
int label_seq = 0;//标签的总数
int max_seq = 0;//生成的临时变量数量

struct TreeNode
{
	struct TreeNode* child[MAXCHILDREN];
	struct TreeNode* sibling;//兄弟
	int lineno;
	int nodekind;	//三个节点类型 stmt exp decl
	int kind;// op const id type var
	union {
		int op;//存储token中的符号
		int val;//数字常量的值
		char* name;
	} attr;			//if语句,while语句,变量声明,id声明等
	int value;		//数字常量的值
	int type; 		// 表达式类型检查
	int temp_var;	// 临时变量
	Label label;  	// 标签
};

TreeNode* newStmtNode(int kind)
{
	TreeNode* t = (TreeNode*)malloc(sizeof(TreeNode));
	int i;
	if (t == NULL)
		printf("Out of memory error at line %d\n", line);
	else {
		for (i = 0; i < MAXCHILDREN; i++) t->child[i] = NULL;
		t->sibling = NULL;
		t->nodekind = StmtK;
		t->kind = kind;
		t->lineno = line++;
		t->type = Void;
		t->label.true_label = "";
		t->label.false_label = "";
		t->label.begin_label = "";
		t->label.next_label = "";
	}
	return t;
}

TreeNode* newExpNode(int kind)
{
	TreeNode* t = (TreeNode*)malloc(sizeof(TreeNode));
	int i;
	if (t == NULL)
		printf("Out of memory error at line %d\n", line);
	else {
		for (i = 0; i < MAXCHILDREN; i++) t->child[i] = NULL;
		t->sibling = NULL;
		t->nodekind = ExpK;
		t->kind = kind;
		t->lineno = line++;
		t->type = Void;
		t->label.true_label = "";
		t->label.false_label = "";
		t->label.begin_label = "";
		t->label.next_label = "";
	}
	return t;
}

TreeNode* newDeclNode(int kind)
{
	TreeNode* t = (TreeNode*)malloc(sizeof(TreeNode));
	int i;
	if (t == NULL)
		printf("Out of memory error at line %d\n", line);
	else {
		for (i = 0; i < MAXCHILDREN; i++) t->child[i] = NULL;
		t->sibling = NULL;
		t->nodekind = DeclK;
		t->kind = kind;
		t->lineno = line++;
		t->type = Void;
		t->label.true_label = "";
		t->label.false_label = "";
		t->label.begin_label = "";
		t->label.next_label = "";
	}
	return t;
}

void Display(struct TreeNode* p);		//显示语法树
void ShowNode(struct TreeNode* p);		//显示某个节点
int CheckNode(struct TreeNode* p);	//检查节点

TreeNode* root;
void gen_header(ostream& out);						//输出头部信息
void gen_code(ostream& out);						//输出代码信息
void gen_decl(ostream& out, TreeNode* t);			//声明信息需要单独打印
void recursive_gen_code(ostream& out, TreeNode* t);	//递归生成代码
void expr_gen_code(ostream& out, TreeNode* t);
void stmt_gen_code(ostream& out, TreeNode* t);

// 临时变量
void set_temp_var(TreeNode* t);

//标签
char* newlabel();
void gen_label();
void recursive_gen_label(TreeNode* t);
void stmt_gen_label(TreeNode* t);
void expr_gen_label(TreeNode* t);
%}

/////////////////////////////////////////////////////////////////////////////
// declarations section

// parser name
%name myparser

// class definition
{
	// place any extra class members here
}

// constructor
{
	// place any extra initialisation code here
}

// destructor
{
	// place any extra cleanup code here
}

// place any declarations here
%include {
#ifndef YYSTYPE
#define YYSTYPE TreeNode*
#endif
extern int lineno;
}

//符号
%token CONST
%token ID

//操作符
%token ADD SUB MUL DIV DELIVERY
%token SADD SSUB GT LT GE LE
%token EQ DEQ NEQ
%token LAND LOR LN AND OR NOT LSHIFT RSHIFT SIZEOF
//标点符号
%token SEMI
%token LP RP 
%token LB RB
%token COMMA
//条件表达式
//if
%token IF
%token ELSE
%token THEN
%token WHILE
%token DO
%token FOR
%token BREAK
%token CONTINUE
%token RETURN
%token INPUT
%token OUTPUT
//定义
%token INT CHAR BOOL DOUBLE FLOAT

%left ADD SUB
%left MUL DIV
%right UMINUS
%right EQ
%%

/////////////////////////////////////////////////////////////////////////////
// rules section

// place your YACC rules here (there must be at least one)

block:ID LP RP LB stmts RB{$$=newStmtNode(CompK);$$->child[0]=$5;root=$$;Display($$);};

stmts:stmt stmts{
	$$->sibling=$2;	
	$$=$1;	
}| stmt{$$=$1;} | stmts mblock stmts{$$->sibling=$2;$2->sibling=$3;$$=$1;};

mblock:LB stmts RB{$$=newStmtNode(CompK);$$->child[0]=$2;};

stmt:expr_stmt{
	$$=$1;
	}
	|if_stmt{
	$$=$1;
	}
	|for_stmt{
	$$=$1;
	}
	|jump_stmt{
	$$=$1;
	}
	|decl_stmt{
	
	$$=$1;
	
	}
	|in_stmt{$$=$1;}	
	|out_stmt{$$=$1;}
	|sem_stmt{$$=NULL;}
	;
sem_stmt:SEMI;

in_stmt:INPUT LP expr RP SEMI{$$=newStmtNode(InputK);$$->child[0]=$3;};

out_stmt:OUTPUT LP expr RP SEMI{$$=newStmtNode(PrintK);$$->child[0]=$3;};

if_stmt:IF LP expr RP stmt {$$=newStmtNode(IfK);$$->child[0]=$3;$$->child[1]=$5;}
		| IF LP expr RP lbock ELSE lbock {
		$$=newStmtNode(IfK);$$->child[0]=$3;$$->child[1]=$5;$$->child[2]=$7;}
		;

for_stmt:FOR LP expr SEMI expr SEMI expr RP lbock
			{
				$$ = newStmtNode(ForK);
				$$->child[0] = $3;
                $$->child[1] = $5;
                $$->child[2] = $7;
                $$->child[3] = $9;
			}
		|FOR LP SEMI expr SEMI expr RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = NULL;
                $$->child[1] = $4;
                $$->child[2] = $6;
                $$->child[3] = $8;
			}
		|FOR LP expr SEMI  SEMI expr RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = $3;
                $$->child[1] = NULL;
                $$->child[2] = $6;
                $$->child[3] = $8;
			}
		|FOR LP expr SEMI expr SEMI  RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = $3;
                $$->child[1] = $5;
                $$->child[2] = NULL;
                $$->child[3] = $8;
			}
		|FOR LP  SEMI  SEMI expr RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = NULL;
                $$->child[1] = NULL;
                $$->child[2] = $5;
                $$->child[3] = $7;
			}
		|FOR LP  SEMI expr SEMI  RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = NULL;
                $$->child[1] = $4;
                $$->child[2] = NULL;
                $$->child[3] = $7;
			}
		|FOR LP expr SEMI  SEMI  RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = $3;
                $$->child[1] = NULL;
                $$->child[2] = NULL;
                $$->child[3] = $7;
			}	
		|FOR LP  SEMI  SEMI  RP lbock{
				$$ = newStmtNode(ForK);
				$$->child[0] = NULL;
                $$->child[1] = NULL;
                $$->child[2] = NULL;
                $$->child[3] = $6;
			}	
		| WHILE LP expr RP lbock	{				
		        $$ = newStmtNode(WhileK);
				$$->child[0] = $3;
                $$->child[1] = $5;}
		;

expr_stmt:expr SEMIS	{$$=$1;}		
		;
		
SEMIS:SEMI;

jump_stmt:BREAK SEMIS{$$=newStmtNode(JumpK);}|
		CONTINUE SEMIS{$$=newStmtNode(JumpK);}|
		RETURN SEMIS{$$=newStmtNode(JumpK);}|
		RETURN expr SEMIS{$$=newStmtNode(JumpK);};

decl_stmt:type id_list SEMI {
		$$ = newDeclNode(VarK);
		$$->child[0]=$1;
		$$->child[1]=$2;
		while($2!=NULL) {
			mymap[$2->attr.name]=$1->type;
			$2->type=$1->type;
			$2=$2->sibling;		
		}
};

type:INT {	
	$$ = newExpNode(TypeK);
    $$->type=Integer;
}
|CHAR {
	$$ = newExpNode(TypeK);
    $$->type=Char;
};
			
id_list:ID{$$=$1;}
		|ID COMMA id_list{$1->sibling=$3;$$=$1;};

lbock:LB stmts RB{$$=$2;if(temp_var_seq>max_seq)max_seq=temp_var_seq;temp_var_seq=0;}
		|stmt{$$=$1;if(temp_var_seq>max_seq)max_seq=temp_var_seq;temp_var_seq=0;}
		;
		
expr:if_expr{$$=$1;}
	 |if_expr EQ expr{
	 $$=newStmtNode(AssignK);
	 $$->child[0]=$1;
	 $$->child[1]=$3;
	 set_temp_var($$);
	 }
	 | expr DIV EQ if_expr{
		$$ = newExpNode(OpK);
		$$ -> attr.op = DIV;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	}
	| expr MUL EQ if_expr {
		$$ = newExpNode(OpK);
		$$ -> attr.op = MUL;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	}
	| expr DELIVERY EQ if_expr{
		$$ = newExpNode(OpK);
		$$ -> attr.op = DELIVERY;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	}
	| expr ADD EQ if_expr{
		$$ = newExpNode(OpK);
		$$ -> attr.op = ADD;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	}
	| expr SUB EQ if_expr{
		$$ = newExpNode(OpK);
		$$ -> attr.op = SUB;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	}
	| expr AND EQ if_expr{
		$$ = newExpNode(OpK);
		$$ -> attr.op = AND;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	}
	| expr OR EQ if_expr{
		$$ = newExpNode(OpK);
		$$ -> attr.op = OR;
		$$ -> child[0] = $1;
		$$ -> child[1] = $4;
		set_temp_var($$);
	};

if_expr:or_expr{$$=$1;};


or_expr:and_expr{$$=$1;}
		|or_expr LOR and_expr{		
	      	$$ = newExpNode(OpK);
	        $$ -> attr.op = LOR;
	        $$ -> child[0] = $1;
	        $$ -> child[1] = $3;
			set_temp_var($$);
		};
		
and_expr:or_bit_expr{$$=$1;}
		|and_expr LAND or_bit_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = LAND;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
				set_temp_var($$);};
		
or_bit_expr:nor_bit_expr{$$=$1;}
			|or_bit_expr OR nor_bit_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = OR;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
                set_temp_var($$);};

nor_bit_expr:and_bit_expr{$$=$1;}
		|nor_bit_expr NOT and_bit_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = NOT;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
                set_temp_var($$);};
		
and_bit_expr:ife_expr{$$=$1;}
		|and_bit_expr AND ife_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = AND;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
                set_temp_var($$);};

ife_expr:jug_expr{$$=$1;}|ife_expr DEQ jug_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = DEQ;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
                set_temp_var($$);}

			|ife_expr NEQ jug_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = NEQ;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
                set_temp_var($$);};

jug_expr:shift_expr{$$=$1;}
|jug_expr GT shift_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = GT;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);}
|jug_expr LT shift_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = LT;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);}
|jug_expr GE shift_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = GE;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);}
|jug_expr LE shift_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = LE;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);};

shift_expr:addsub_expr{$$=$1;}
|shift_expr LSHIFT addsub_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = LSHIFT;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);}
|shift_expr RSHIFT addsub_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = RSHIFT;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);};

addsub_expr:muldiv_expr{$$=$1;}
|addsub_expr ADD muldiv_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = ADD;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
				set_temp_var($$);}
|addsub_expr SUB muldiv_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SUB;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;
				set_temp_var($$);};

muldiv_expr:uo_expr{$$=$1;}
|muldiv_expr MUL uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = MUL;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);}
|muldiv_expr DIV uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = DIV;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);}
|muldiv_expr DELIVERY uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = DELIVERY;
                $$ -> child[0] = $1;
                $$ -> child[1] = $3;set_temp_var($$);};


uo_expr:post_expr{$$=$1;}|ADD uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = ADD;
                $$ -> child[0] = $2;set_temp_var($$);}
                |SUB uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SUB;
                $$ -> child[0] = $2;set_temp_var($$);}
                |SADD uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SADD;
                $$ -> child[0] = $2;set_temp_var($$);}
                |uo_expr SADD{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SADD;
                $$ -> child[0] = $1;set_temp_var($$);}
                |SSUB uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SSUB;
                $$ -> child[0] = $2;set_temp_var($$);}
                |uo_expr SSUB{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SSUB;
                $$ -> child[0] = $1;set_temp_var($$);}
                |MUL uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = MUL;
                $$ -> child[0] = $2;set_temp_var($$);}
                |LN uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = LN;
                $$ -> child[0] = $2;set_temp_var($$);}
                |AND uo_expr{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = AND;
                $$ -> child[0] = $2;set_temp_var($$);}
                |SIZEOF LP uo_expr RP{      
				$$ = newExpNode(OpK);
                $$ -> attr.op = SIZEOF;
                $$ -> child[0] = $3;set_temp_var($$);};

post_expr:basic_expr{$$=$1;};

basic_expr:ID{$$=$1;}|CONST{$$=$1;}| LP expr RP{$$=$2;};

%%

/////////////////////////////////////////////////////////////////////////////
// programs section
void Display(struct TreeNode* p)//显示语法树
{
	struct TreeNode* temp;
	for (int i = 0; i < MAXCHILDREN; i++) {
		if (p->child[i] != NULL)
			Display(p->child[i]);//递归打印孩子结点
	}
	if (err)
		return;
	if (!CheckNode(p)) {
		err = 1;
		return;
	}
	ShowNode(p); 		//打印自己
	temp = p->sibling;
	if (temp != NULL) {
		Display(temp);	//打印兄弟
	}
	return;
}

int CheckNode(struct TreeNode* p) {  //类型检查
	char* types[4] = { "Void","Integer ","Char","Boolean" };
	struct TreeNode* temp;
	switch (p->nodekind) {
		case StmtK:
			switch (p->kind) {
				case IfK:
					if (p->child[0]->type != Boolean) {
						printf("%s \n", "IF  ERROR!!!");
					}
					break;
				case WhileK: 
					if (p->child[0]->type != Boolean && p->child[0]->type != Integer) {
						printf("%s \n", "WHILE  ERROR!!!");
					}
					break;
				case AssignK: 
					if (p->child[0]->type != p->child[1]->type) {
						printf("%s \n", "ASSIGN ERROR!!!");
					}
					p->type = p->child[0]->type;
					break;
				case ForK: 
					if (p->child[1]->type != Boolean && p->child[1] != NULL) {
						printf("%s \n", "FOR ERROR!!!");
					}
					break;
				case PrintK: 
					if (p->child[0]->type != Integer && p->child[0]->type != Char) {
						printf("%s \n", "PRINT ERROR!!!");
					}
					break;
			}
			break;
		case ExpK:
			char* names[5] = { "Expr," , "Const Declaration,", "ID Declaration,","Type Specifier,","CK" };
			switch (p->kind) {
				case OpK:
					switch (p->attr.op) {
						case ADD:
							if (p->child[0]->type != p->child[1]->type)
								printf("ADD,error \n");
							p->type = p->child[0]->type;
							break;
						case SUB:
							if (p->child[0]->type != p->child[1]->type)
								p->type = p->child[0]->type;
							break;
						case MUL:
							if (p->child[0]->type != p->child[1]->type)
								printf("MUL,error \n");
							p->type = p->child[0]->type;
							break;
						case DIV:
							if (p->child[0]->type != p->child[1]->type)
								printf("DIV,error \n");
							p->type = p->child[0]->type;
							break;
						case DELIVERY:
							if (p->child[0]->type != p->child[1]->type)
								p->type = p->child[0]->type;
							break;
						case SADD:
							if (p->child[0]->type != Integer)
								printf("++,error\n");
							p->type = p->child[0]->type;
							break;
						case SSUB:
							if (p->child[0]->type != Integer)
								printf("--,error\n");
							p->type = p->child[0]->type;
							break;
						case LT:
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Integer)
								printf("LT,error \n");
							p->type = Boolean;
							break;
						case LE:
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Integer)
								printf("LE,error \n");
							p->type = Boolean;
							break;
						case GT:
						{
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Integer)
								printf("GT,error \n");
							p->type = Boolean;
							break;
						}
						case GE:
						{
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Integer)
								printf("GE,error \n");
							p->type = Boolean;
							break;
						}
						case DEQ:
						{
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Integer)
								printf("DEQ,error \n");
							p->type = Boolean;
							break;
						}
						case NEQ:
						{
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Integer)
								printf("NEQ,error \n");
							p->type = Boolean;
							break;
						}
						case LOR:
						{
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Boolean)
								printf("LOR,error \n");
							p->type = Boolean;
							break;
						}
						case LAND:
						{
							if (p->child[0]->type != p->child[1]->type || p->child[0]->type != Boolean)
								printf("LAND,error \n");
							p->type = Boolean;
							break;
						}
						case LN:
							if (p->child[0]->type != Boolean)
								printf("!,error\n");
							p->type = Boolean;
							break;
					}
					break;
				case ConstK:
					p->type = Integer;
					break;//数字常量
				case CK:
					p->type = Char;
					break;//常量
				case IdK:
				case TypeK:
					break;
			}
			break;
		case DeclK:
			break;
	}
	return 1;
}

void ShowNode(struct TreeNode* p)//显示某个节点
{
	char* types[4] = { "Void","Integer ","Char","Boolean" };
	struct TreeNode* temp;
	printf("%d:", p->lineno);//行号
	switch (p->nodekind)
	{
	case StmtK:
	{	//
		char* names[7] = { "If_statement,",  "While_statement," ,"Assign_statement," , "For_statement," , "Compound_statement,","Input_statement,","Print_statement," };
		printf("%s\t\t\t", names[p->kind]);//可以直接从数组里面打印，一一对应
		break;
	}

	case ExpK:
	{
		char* names[5] = { "Expr," , "Const Declaration,", "ID Declaration,","Type Specifier,","CK" };
		printf("%s\t", names[p->kind]);

		switch (p->kind)
		{
		case OpK:
		{
			switch (p->attr.op)
			{
			case ADD:
			{
				printf("\t\top:+\t\t");
				break;
			}
			case SUB:
			{
				printf("\t\top:-\t\t");
				break;
			}
			case MUL:
			{
				printf("\t\top:*\t\t");
				break;
			}
			case DIV:
			{
				printf("\t\top:/\t\t");
				break;
			}
			case DELIVERY:
			{
				printf("\t\top:%s\t\t", "%");
				break;
			}
			case SADD:
			{
				printf("\t\top:++\t\t");
				break;
			}
			case SSUB:
			{
				printf("\t\top:--\t\t");
				break;
			}
			case LT:
			{
				printf("\t\top:<\t\t");
				break;
			}
			case LE:
			{
				printf("\t\top:<=\t\t");
				break;
			}
			case GT:
			{
				printf("\t\top:>\t\t");
				break;
			}
			case GE:
			{
				printf("\t\top:>=\t\t");
				break;
			}
			case DEQ:
			{
				printf("\t\top:==\t\t");
				break;
			}
			case NEQ:
			{
				printf("\t\top:!=\t\t");
				break;
			}
			case LOR:
			{
				printf("\t\top:||\t\t");
				break;
			}
			case LAND:
			{
				printf("\t\top:&&\t\t");
				break;
			}
			case LN:
			{
				printf("\t\top:!\t\t");
				break;
			}
			}
			break;
		}
		case ConstK:
		{
			printf("values: %d\t", p->attr.val);
			break;//数字常量
		}
		case CK:
		{
			printf("values: %s\t", p->attr.name);
			break;//数字常量
		}
		case IdK:
		{
			printf("symbol: %s \t", p->attr.name);
			break;//字符
		}
		case TypeK:
		{
			printf("%s\t", types[p->type]);
			break;
		}
		}
		break;
	}
	case DeclK:
	{
		char names[2][20] = { "Var Declaration, ", "other" };
		printf("%s\t\t\t", names[p->kind]);
		break;
	}

	}
	printf("children: ");
	for (int i = 0; i < MAXCHILDREN; i++) {
		if (p->child[i] != NULL)
		{
			printf("%d  ", p->child[i]->lineno);//输出所有孩子结点
			temp = p->child[i]->sibling;

			while (temp != NULL)//有兄弟打印兄弟节点
			{
				printf("%d  ", temp->lineno);
				temp = temp->sibling;
			}

		}
	}
	printf("\t\t %s:", types[p->type]);
	printf("\n");
	return;
}

//代码生成
void gen_header(ostream& out)//打印头部
{
	out << "\t.586" << endl;
	out << "\t.model flat, stdcall" << endl;
	out << "\toption casemap :none" << endl;
	out << endl;
	out << "\tinclude macros.asm" << endl;
	out << "\tinclude msvcrt.inc" << endl;
	out << "\tincludelib msvcrt.lib" << endl;
}

void gen_code(ostream& out)
{
	int i = 0;
	//打印头部
	gen_header(out);

	TreeNode* p = root->child[0];
	out << endl << endl << "\t.data" << endl;
	for (; p->nodekind == DeclK; p = p->sibling)
		gen_decl(out, p);//输出变量声明语句

	//临时变量的声明语句
	for (i = 0; i < max_seq; i++)
		out << "\t\tt" << i << " DWORD 0" << endl;
	out << "\t\tbuffer BYTE 128 dup(0)" << endl;
	out << "\t\tLF BYTE 13, 10, 0" << endl;
	out << "\thint_end BYTE 'Press any key to continue',0" << endl;

	out << endl << endl << "\t.code" << endl;
	out << "_start:" << endl;

	for (; p; p = p->sibling) {
		recursive_gen_code(out, p);//输出代码生成语句
	}
	out << "\tinvoke crt_printf,  addr hint_end" << endl;
	out << "\tinvoke crt__getch" << endl << "\tinvoke crt__exit, 0" << endl;
	out << "END _start" << endl;
}

// 声明代码
void gen_decl(ostream& out, TreeNode* t)
{
	if (t->child[0]->type == Integer) {
		for (TreeNode* p = t->child[1]; p != NULL; p = p->sibling)
			out << "\t\t_" << p->attr.name << " DWORD 0" << endl;
		return;
	}
	if (t->child[0]->type == Char) {
		for (TreeNode* p = t->child[1]; p != NULL; p = p->sibling)
			out << "\t\t_" << p->attr.name << " DWORD 0" << endl;
		return;
	}
	else
		cout << t->lineno << "不符合格式要求";
	return;
}

// 递归地生成语句、表达式的代码
void recursive_gen_code(ostream& out, TreeNode* t)
{
	if (t != NULL) {
		if (t->nodekind == StmtK)
			stmt_gen_code(out, t);
		else if (t->nodekind == ExpK && t->kind == OpK)
			expr_gen_code(out, t);
	}
}

void stmt_gen_code(ostream& out, TreeNode* t) 
{
	switch (t->kind) {
	case IfK:
	{
		TreeNode* s2 = t->child[2];
		if (s2 == NULL) {//if (e) s1
			{TreeNode* e = t->child[0]; TreeNode* s1 = t->child[1];
			recursive_gen_code(out, e);//e S1 
			out << e->label.true_label << ":ww" << endl;
			for (; s1; s1 = s1->sibling) {
				recursive_gen_code(out, s1);
			}}
		}
		else {//if(e)s1 else s2 
			TreeNode* e = t->child[0]; TreeNode* s1 = t->child[1]; TreeNode* s2 = t->child[2];
			recursive_gen_code(out, e);
			out << e->label.true_label << ":" << endl;
			for (; s1; s1 = s1->sibling) {
				recursive_gen_code(out, s1);
			}
			out << "\tJMP " << t->label.next_label << endl;
			out << e->label.false_label << ":" << endl;
			for (; s2; s2 = s2->sibling)
				recursive_gen_code(out, s2);
		}
		if (t->label.next_label != "")
			out << t->label.next_label << ":" << endl;
		return;
	}
	case AssignK:
	{
		TreeNode* e1 = t->child[0]; TreeNode* e2 = t->child[1];
		expr_gen_code(out, e2);
		out << "\tMOV eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else if (e2->kind == CK)
			out << 80;
		else out << "t" << e2->temp_var;
		out << endl;
		out << "\tMOV _" << e1->attr.name << ", eax" << endl;
		return;
	}
	case WhileK: //while(e) s1
	{
		TreeNode* e = t->child[0];
		TreeNode* s1 = t->child[1];

		out << t->label.begin_label << ":" << endl;
		recursive_gen_code(out, e);
		out << e->label.true_label << ":" << endl;

		recursive_gen_code(out, s1);
		out << "\tJMP " << t->label.begin_label << endl;
		if (t->label.next_label != "")
			out << t->label.next_label << ":" << endl;
		return;
	}
	case ForK: //for(e;s1;s2) s3
	{
		TreeNode* e = t->child[0];
		TreeNode* s1 = t->child[1];
		TreeNode* s2 = t->child[2];
		TreeNode* s3 = t->child[3];

		recursive_gen_code(out, e);					//初始化
		out << t->label.begin_label << ":" << endl;	//开始
		recursive_gen_code(out, s1);				//判断语句，从此处跳走
		out << s1->label.true_label << ":" << endl;	//循环体标号
		recursive_gen_code(out, s3);				//循环体
		recursive_gen_code(out, s2);				//每次循环后的变化
		out << "\tJMP " << t->label.begin_label << endl;

		if (t->label.next_label != "")
			out << t->label.next_label << ":" << endl;
		return;
	}
	case CompK:
		for (TreeNode* p = t->child[0]; p; p = p->sibling)
			recursive_gen_code(out, p);
		out << endl;
		return;
	case InputK:
	{
		TreeNode* e = t->child[0];
		if (e->kind != OpK) {
			if (mymap[e->attr.name] == Integer)
				out << "\tinvoke crt_scanf,SADD('%d',13,10),addr _" << e->attr.name << endl;
			if (mymap[e->attr.name] == Char)
				out << "\tinvoke crt_scanf,SADD('%c',0),addr _" << e->attr.name << endl;
		}
		else {
			recursive_gen_code(out, e);
			out << "\tinvoke crt_scanf,SADD('%d',13,10),t" << e->temp_var << endl;
		}
		return;
	}
	case PrintK:
	{
		TreeNode* e = t->child[0];
		if (e->kind != OpK) {
			if (mymap[e->attr.name] == Integer)
				out << "\tinvoke crt_printf,SADD('%d',13,10), _" << t->child[0]->attr.name << endl;
			if (mymap[e->attr.name] == Char)
				out << "\tinvoke crt_printf,SADD('%c',13,10), _" << t->child[0]->attr.name << endl;
		}
		else {
			recursive_gen_code(out, e);
			out << "\tinvoke crt_printf,SADD('%d',13,10),t" << e->temp_var << endl;
		}
		return;
	}
	}
}

void expr_gen_code(ostream& out, TreeNode* t) {
	//{OpK,ConstK,IdK,TypeK,CK};
	int i;
	if (t->attr.op != LAND && t->attr.op != LOR && t->attr.op != LN)
		for (i = 0; i < MAXCHILDREN && t->child[i] != NULL; i++)
			recursive_gen_code(out, t->child[i]);  //为了优先级，先考虑子节点
	TreeNode* e1 = t->child[0];
	TreeNode* e2 = t->child[1];
	switch (t->attr.op) {
	case ADD:
	{
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;
		out << "\tADD eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;
		out << "\tMOV t" << t->temp_var << ", eax" << endl;   //临时变量
		break;
	}
	case SUB:
	{
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;
		out << "\tSUB eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;
		out << "\tMOV t" << t->temp_var << ", eax" << endl;   //临时变量
		break;
	}
	case MUL:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else
			out << "t" << e1->temp_var;
		out << endl;					//param1
		out << "\tIMUL eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else
			out << "t" << e2->temp_var;
		out << endl;					//param2
		out << "\tMOV t" << t->temp_var << ", eax" << endl;   //临时变量
		break;
	case DIV:
		//除法先将dx置0
		out << "\tXOR dx,dx" << endl;		//被除数高位清零（AX存放低16位，DX存放高16位）
		out << "\tMOV eax, ";			//被除数放入eax中
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else
			out << "t" << e1->temp_var;
		out << endl;

		out << "\tMOV ebx,";			//除数放入ebx中
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;
		out << "\tDIV bx" << endl;			//进行除法
		out << "\tXOR ah,ah" << endl;		//将余数置0
		out << "\tMOV t" << t->temp_var << ", eax" << endl;
		break;
	case DELIVERY:
		break;
	case SADD:
		out << "\tMOV eax,_" << e1->attr.name << endl;
		out << "\tADD eax, 1" << endl;
		out << "\tMOV _" << e1->attr.name << ", eax" << endl;   //临时变量
		break;
	case SSUB:
		out << "\tMOV eax,_" << e1->attr.name << endl;
		out << "\tSUB eax, 1" << endl;
		out << "\tMOV _" << e1->attr.name << ", eax" << endl;   //临时变量
		break;
	case LT:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;   //param1
		out << "\tCMP eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;//param2
		out << "\tJL " << t->label.true_label << endl;
		out << "\tJMP " << t->label.false_label << endl;
		break;
	case LE:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;   //param1
		out << "\tCMP eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;//param2
		out << "\tJNG " << t->label.true_label << endl;
		out << "\tJMP " << t->label.false_label << endl;
		break;
	case GT:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;   //param1
		out << "\tCMP eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;//param2
		out << "\tJG " << t->label.true_label << endl;
		out << "\tJMP " << t->label.false_label << endl;
		break;
	case GE:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;   //param1
		out << "\tCMP eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;//param2
		out << "\tJGE " << t->label.true_label << endl;
		out << "\tJMP " << t->label.false_label << endl;
		break;
	case DEQ:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;   //param1
		out << "\tSUB eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;//param2
		out << "\tJZ " << t->label.true_label << endl;
		out << "\tJMP " << t->label.false_label << endl;
		break;
	case NEQ:
		out << "\tMOV eax, ";
		if (e1->kind == IdK)
			out << "_" << e1->attr.name;
		else if (e1->kind == ConstK)
			out << e1->attr.val;
		else out << "t" << e1->temp_var;
		out << endl;   //param1
		out << "\tSUB eax, ";
		if (e2->kind == IdK)
			out << "_" << e2->attr.name;
		else if (e2->kind == ConstK)
			out << e2->attr.val;
		else out << "t" << e2->temp_var;
		out << endl;//param2
		out << "\tJNZ " << t->label.true_label << endl;
		out << "\tJMP " << t->label.false_label << endl;
		break;
	case LOR:
		recursive_gen_code(out, e1);
		out << e1->label.false_label << ":" << endl;
		recursive_gen_code(out, e2);
		break;
	case LAND:
		recursive_gen_code(out, e1);
		out << e1->label.true_label << ":" << endl;
		recursive_gen_code(out, e2);
		break;
	case LN:
		recursive_gen_code(out, e1);
		break;
	}
}

void set_temp_var(TreeNode* t) {
	if (t->nodekind != ExpK)
		return;  // 不是表达式直接return
	// 若子节点为运算符表达式
	if (t->child[0]->nodekind == ExpK && t->child[0]->kind == OpK)
		temp_var_seq--;  // 全局变量，初始化为0
	if (t->child[1] != NULL && t->child[1]->nodekind == ExpK && t->child[1]->kind == OpK)
		temp_var_seq--;
	t->temp_var = temp_var_seq;
	temp_var_seq++;
}

//对标签进行处理
char* newlabel() {
	char* temp = new char[10];
	sprintf_s(temp, 10, "L%d", label_seq);
	label_seq++;
	return temp;
}  // 产生新的标签

void gen_label()
{
	TreeNode* t = root->child[0];  // 对所有的复合语句进行声明
	for (; t->nodekind == DeclK; t = t->sibling);  // 声明语句在开头
	for (; t; t = t->sibling)
		recursive_gen_label(t);  // 遍历兄弟节点，对label进行分析
}

// 递归地生成标签
void recursive_gen_label(TreeNode* t)//递归调用
{
	int i;
	if (t != NULL) {
		if (t->nodekind == StmtK)
			stmt_gen_label(t);
		else if (t->nodekind == ExpK)
			expr_gen_label(t);
		for (i = 0; i < MAXCHILDREN; i++)
			recursive_gen_label(t->child[i]);
	}
}

void stmt_gen_label(TreeNode* t)//标号的产生
{
	TreeNode* e = t->child[0];
	TreeNode* s1 = t->child[1];
	TreeNode* s2 = t->child[2];
	TreeNode* s3 = t->child[3];
	int i;
	switch (t->kind) {
	case IfK:
		if (s2 == NULL) {//if(e) s1
			if (e->label.true_label == "")
				e->label.true_label = newlabel();
			if (t->label.next_label == "")
				t->label.next_label = newlabel();
			e->label.false_label = t->label.next_label;
			s1->label.next_label = t->label.next_label;
		}
		else {//if(e) s1 else s2
			if (e->label.true_label == "")
				e->label.true_label = newlabel();
			if (t->label.next_label == "")
				t->label.next_label = newlabel();
			e->label.false_label = newlabel();
			s1->label.next_label = t->label.next_label;
			s2->label.next_label = t->label.next_label;
		}
		break;
	case WhileK://while(e) s1
		t->label.begin_label = newlabel();
		e->label.true_label = newlabel();
		if (t->label.next_label == "")
			t->label.next_label = newlabel();
		e->label.false_label = t->label.next_label;
		s1->label.next_label = t->label.begin_label;
		break;
	case ForK: //for(e;s1;s2) s3
		t->label.begin_label = newlabel();
		s1->label.true_label = newlabel();
		if (t->label.next_label == "")
			t->label.next_label = newlabel();
		s1->label.false_label = t->label.next_label;
		s1->label.next_label = t->label.begin_label;
		break;
	case CompK: // 复合语句，递归
		TreeNode* p = t->child[0];
		for (; p; p = p->sibling) {
			if (p->sibling == NULL)
				p->label.next_label = t->label.next_label;
			recursive_gen_label(p);
		}
		break;
	}
}

void expr_gen_label(TreeNode* t)
{
	TreeNode* e1 = t->child[0];
	TreeNode* e2 = t->child[1];
	switch (t->attr.op) {
	case LAND: //&&
		if (e1->label.true_label == "")
			e1->label.true_label = newlabel();
		if (t->label.false_label == "")
			t->label.false_label = newlabel();
		if (t->label.true_label == "")
			t->label.true_label = newlabel();
		e2->label.true_label = t->label.true_label;
		// 三者假值出口相同
		e1->label.false_label = e2->label.false_label = t->label.false_label;
		break;
	case LOR:
		if (t->label.true_label == "")
			t->label.true_label = newlabel();
		if (t->label.false_label == "")
			t->label.false_label = newlabel();
		e1->label.false_label = newlabel();
		e2->label.false_label = t->label.false_label;
		// 三者真值出口相同
		e1->label.true_label = e2->label.true_label = t->label.true_label;
		break;
	case LN:
		if (t->label.true_label == "")
			t->label.true_label = newlabel();
		if (t->label.false_label == "")
			t->label.false_label = newlabel();
		e1->label.false_label = t->label.true_label;
		e1->label.true_label = t->label.false_label;
		break;
	}
}

int main(void)
{
	int  n = 1;
	mylexer lexer;
	myparser parser;
	if (parser.yycreate(&lexer)) {
		if (lexer.yycreate(&parser)) {
			ifstream in("input.txt");  // 输入代码
			lexer.yyin = &in;
			n = parser.yyparse();
		}
	}
	gen_label();	//标号设置
	gen_code(out);	//代码生成
	cout << "**********************************\n";
	cout << "结束！\n";
	return n;
}