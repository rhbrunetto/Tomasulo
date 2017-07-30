#include <stdio.h>
#include <string.h>

#ifndef CLOCK_H
#define CLOCK_H

#include "cache.h"
#include "processador.h"
#include "registradores.h"
#include "memoria.h"

/*start do clock*/
void clock_start();
void clock_finish();
void call_clock();

#endif
