%{
#define START_ADDRESS_DATA 0x10000000
#define FLAG_ASSEMBLER 1
#define FLAG_DEFINER   0
#define BYTE_SIZE      4

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lib/assembler.util.h"
#include "../definitions.h"

LinkedList lista;

int address = 0, passada = 0, dados_offset = START_ADDRESS_DATA, data_Bytes = 0;
char * error_msg = "Instrução não definida\n";

FILE* yyin;
char * mnemonico;
int state;

typedef struct{
  int numeros[10];
  int qtdNum;
}NumStruct;

NumStruct nstruct;

%}

%union{
  struct R_type{
    int opcode, rd, rs, rt, func, shift;
  }instruction_R;
  struct J_type{
    int opcode, target;
  }instruction_J;
  struct I_type{
    int opcode, rs, rt, imm;
  }instruction_I;
  int valor;
  char *str;
}

/* declare tokens */
%token ABRE_PAR
%token FECHA_PAR
%token <valor> NUMBER
%token ECOM
%token <str> ADDRESS IDENTIFICADOR
%token <valor> REG_S REG_AT REG_T REG_A REG_V REG_K REG_GP REG_SP REG_FP REG_RA REG_ZERO
%token <instruction_R> ADD ADDU AND CLO CLZ DIV DIVU MULT MULTU MUL MADD MADDU MSUB MSUBU NOR OR SLL SLLV SRA SRAV SRL SRLV SUB SUBU XOR SLT SLTU TEQ TNE TGE TGEU TLT TLTU MFHI MFLO MTHI MTLO MOVZ MOVF MOVT ERET SYSCALL BREAK NOP
%token <instruction_I> ADDI ADDIU ANDI ORI XORI LUI SLTI SLTIU BEQ BGEZ BGEZAL BGTZ BLEZ BLTZAL BLTZ BNE TEQI TNEQ TGEI TGEIU TLTI TLTIU LB LBU LH LHU LW LWL LWR LL SB SH SW SWR SWL SC
%token <instruction_J> J JAL JALR JR
%token DATA TEXT SECTION DPTS INT EOL COMMA
%token <str> HEX_VAL

%type <valor> nrorlabel
%type <str> reg
%type <instruction_R> instrucao_R
%type <instruction_I> instrucao_I
%type <instruction_J> instrucao_J
%type <valor> nro

%%
all: general
   | assembly

general: spec eol definitions

spec: ECOM IDENTIFICADOR DPTS NUMBER eol ECOM IDENTIFICADOR DPTS NUMBER eol ECOM IDENTIFICADOR DPTS NUMBER eol ECOM IDENTIFICADOR DPTS NUMBER{
        QUANTIDADE_ESTACOES_RESERVA_ADD = $4;
        QUANTIDADE_ESTACOES_RESERVA_MUL = $9;
        QUANTIDADE_ESTACOES_RESERVA_LOAD = $14;
        QUANTIDADE_ESTACOES_RESERVA_STORE = $19;
        QUANTIDADE_ESTACOES_RESERVA = $4 + $9 + $14 + $19;
      }

definitions: |
            definitions ABRE_PAR IDENTIFICADOR DPTS NUMBER COMMA NUMBER COMMA IDENTIFICADOR COMMA IDENTIFICADOR FECHA_PAR eol {
             Def * d = (Def *)malloc(sizeof(Def));
             d->mnemonic = $3;
             d->opcode = $5;
             d->ciclos = $7;
             d->formato = get_formato_based($9);
             d->tipo_uf = get_uf_based($11);
             d->function = -1; /*Não possuem Function*/
             d->abstract_opcode = $5; /*Não possuem Abstract Opcode*/
             insertLinkedList(&lista_definicoes, d);
           } |
           definitions ABRE_PAR IDENTIFICADOR DPTS NUMBER COMMA NUMBER COMMA IDENTIFICADOR COMMA IDENTIFICADOR COMMA NUMBER COMMA NUMBER FECHA_PAR eol {
             Def * d = (Def *)malloc(sizeof(Def));
             d->mnemonic = $3;
             d->opcode = $5;
             d->ciclos = $7;
             d->formato = get_formato_based($9);
             d->tipo_uf = get_uf_based($11);
             d->function = $13;
             d->abstract_opcode = $15;
             insertLinkedList(&lista_definicoes, d);
           }

eol:
  | eol EOL


assembly: data_section eol text_section

data_section:
            | DATA eol variaveis {}

text_section:
            | TEXT eol lista_instrucoes

variaveis:
         | variaveis variavel eol

variavel: IDENTIFICADOR DPTS INT numeros eol {if(passada == 0){
                                                SLabel * var = (SLabel *)malloc(sizeof(SLabel));
                                                var->lbl_identificador = $1;
                                                var->lbl_offset = dados_offset;
                                                printf("Defined var %s \n", $1);
                                                insertLinkedList(&lista, var);
                                                printf("inserted\n");
                                                dados_offset += (nstruct.qtdNum * BYTE_SIZE);
                                                printf("\nNew dados_offset: %d\n", dados_offset);
                                              }else{
                                                printf("\nSetting data!\n");
                                                setData(getOffset(&lista, $1), nstruct.numeros, nstruct.qtdNum);
                                                printf("\nSetted data!\n");
                                              } nstruct.qtdNum = 0;}

numeros: nro {nstruct.numeros[nstruct.qtdNum] = $1; nstruct.qtdNum = nstruct.qtdNum +1;}
       | nro comma numeros {nstruct.numeros[nstruct.qtdNum] = $1; nstruct.qtdNum = nstruct.qtdNum +1;}

nro: NUMBER | HEX_VAL {$$ = hex_to_dec($1);}

nrorlabel: NUMBER | HEX_VAL {$$ = hex_to_dec($1);} | IDENTIFICADOR {$$ = getOffset(&lista, $1);}

comma:
     | COMMA

lista_instrucoes:
                | lista_instrucoes label_decl instrucao eol

label_decl:
          | IDENTIFICADOR DPTS eol {if(passada == 0){
                                      printf("\n\tDefining new label: %s\n", $1);
                                      SLabel * label_found = (SLabel *)malloc(sizeof(SLabel));
                                      label_found->lbl_identificador = $1;
                                      label_found->lbl_offset = address;
                                      printf("Defined lbl %s \n", $1);
                                      insertLinkedList(&lista, label_found);
                                      printf("inserted\n");
                                    }}

instrucao: instrucao_R {if(passada == 1){ setInstruction_R($1.opcode, $1.rs, $1.rt, $1.rd, $1.shift, $1.func); }else{ address += BYTE_SIZE; }}
         | instrucao_I {if(passada == 1){ setInstruction_I($1.opcode, $1.rs, $1.rt, $1.imm); }else{ address += BYTE_SIZE; }}
         | instrucao_J {if(passada == 1){ setInstruction_J($1.opcode, $1.target); }else{ address += BYTE_SIZE; }}

instrucao_R: ADD reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | ADDU reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | AND reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | CLO reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | CLZ reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | DIV reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | DIVU reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | MULT reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | MULTU reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | MUL reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | MSUB reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | MSUBU reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | NOR reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | OR reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | SLL reg comma reg comma nro {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = 0; $$.rt = $4; $$.shift = $6; $$.func = d->function;}}
           | SLLV reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $6; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | SRA reg comma reg comma nro {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = 0; $$.rt = $4; $$.shift = $6; $$.func = d->function;}}
           | SRAV reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $6; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | SRL reg comma reg comma nro {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = 0; $$.rt = $4; $$.shift = $6; $$.func = d->function;}}
           | SRLV reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $6; $$.rt = $4; $$.shift = 0; $$.func = d->function;}}
           | SUB reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | SUBU reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | XOR reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | SLT reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | SLTU reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | JALR reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | JALR reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 31; $$.rs = $2; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | JR reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | MFHI reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = 0; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | MFLO reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = 0; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | MTHI reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | MTLO reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = $2; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | MOVN reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | MOVZ reg comma reg comma reg {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = $2; $$.rs = $4; $$.rt = $6; $$.shift = 0; $$.func = d->function;}}
           | SYSCALL {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = 0; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}
           | NOP {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rd = 0; $$.rs = 0; $$.rt = 0; $$.shift = 0; $$.func = d->function;}}


instrucao_J: J IDENTIFICADOR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.target = getOffset(&lista, $2);}}
           | JAL IDENTIFICADOR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.target = getOffset(&lista, $2);}}

instrucao_I: ADDI reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | ADDIU reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | ANDI reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | ORI reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | XORI reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | LUI reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = 0; $$.imm = $4;}}
           | SLTI reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | SLTIU reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $4; $$.imm = $6;}}
           | BEQ reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $4; $$.rs = $2; $$.imm = $6;}}
           | BGEZ reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = 1; $$.rs = $2; $$.imm = $4;}}
           | BGEZAL reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = 17; $$.rs = $2; $$.imm = $4;}}
           | BGTZ reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = 0; $$.rs = $2; $$.imm = $4;}}
           | BLEZ reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = 0; $$.rs = $2; $$.imm = $4;}}
           | BLTZAL reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = 16; $$.rs = $2; $$.imm = $4;}}
           | BLTZ reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = 0; $$.rs = $2; $$.imm = $4;}}
           | BNE reg comma reg comma nrorlabel {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $4; $$.rs = $2; $$.imm = $6;}}
           | LB reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | LBU reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | LH reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | LHU reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | LW reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | LWL reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | LWR reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | SB reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | SH reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | SW reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | SWL reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}
           | SWR reg comma nro ABRE_PAR reg FECHA_PAR {if(passada == 1){ Def * d = get_def_mnemonico(mnemonico); if(d==NULL) yyerror(error_msg); $$.opcode = d->opcode; $$.rt = $2; $$.rs = $6; $$.imm = $4;}}

reg: REG_S {$$ = $1;}
   | REG_AT {$$ = $1;}
   | REG_T {$$ = $1;}
   | REG_A {$$ = $1;}
   | REG_V {$$ = $1;}
   | REG_K {$$ = $1;}
   | REG_GP {$$ = $1;}
   | REG_SP {$$ = $1;}
   | REG_FP {$$ = $1;}
   | REG_RA {$$ = $1;}
   | REG_ZERO {$$ = $1;}

%%

void call_tradutor(FILE *f){
  state = FLAG_ASSEMBLER;
  nstruct.qtdNum = 0;
  printf("\nParsing!\n");
  inicializarLista(&lista);

  passada = 0;
  if(f == NULL){
    printf("\nArquivo inválido para o tradutor!\n");
    return;
  }

  yyrestart(f);

  yyparse();

  print_lista_labels(&lista);

  passada = 1;
  rewind(f);
  printf("\nPassada 1\n");
  yyparse();

  printf("\nParsed!\n");

}

int get_uf_based(char * uf){
  if(!strcmp(uf, "ADD_UF"))
      return ADD_UF;
  else if(!strcmp(uf, "MUL_UF"))
      return MUL_UF;
  else if(!strcmp(uf, "LOAD_UF"))
      return LOAD_UF;
  else if(!strcmp(uf, "STORE_UF"))
      return STORE_UF;
  else
      yyerror("TIPO INVÁLIDO DE UNIDADE FUNCIONAL");
}

int get_formato_based(char * formato){
  if(!strcmp(formato, "TYPE_R"))
      return TYPE_R;
  else if(!strcmp(formato, "TYPE_J"))
      return TYPE_J;
  else if(!strcmp(formato, "TYPE_I"))
      return TYPE_I;
  else
      yyerror("TIPO INVÁLIDO DE INSTRUÇÃO");
}

int run_definitions(){
  state = FLAG_DEFINER;
  inicializarLista(&lista_definicoes);
  yyin = fopen("include/lib/parser_def/def_file.txt", "r");
  do {
		yyparse();
	} while (!feof(yyin));
}

int yyerror(char *s) {
  fprintf(stderr, "error: %s\n", s);
  return 0;
}
