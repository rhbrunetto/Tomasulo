#ifndef CACHE_H
#define CACHE_H

#include "barramentos.h"
#include "memoria.h"

#define CACHE_LINE_COUNT 2048 /*São 2K linhas*/
#define CACHE_LINE_SIZE  4    /*Cada linha com 4 palavras*/

typedef struct{
  Byte campos[CACHE_LINE_SIZE][WORD_SIZE];
  short int tag;
  short int update; /*Poderia ser um bit*/
}Linha;

typedef struct{
  Linha linhas[CACHE_LINE_COUNT];
}Cache;

void inicializar_cache();
void cache_print();
void cache_next();
void cache_controller_next();

#endif
