%option yylineno
%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "RobotControl.tab.h"
%}
%%

[ \t\n]+        ; // Пропуск пробелов и символов новой строки

"if"            { return IF; }        // Обнаружено ключевое слово "if"
"else"          { return ELSE; }      // Обнаружено ключевое слово "else"
"while"         { return WHILE; }
"destroy"      { return DES; }        // Обнаружена команда "destroy"
"makeup"      { return M; }           // Обнаружена команда "makeup"
"drop"         { return D; }         // Обнаружена команда "drop"
"("             { return OB; }        // Обнаружен символ "("
")"             { return CB; }        // Обнаружен символ ")"
"{"             { return FOB; }       // Обнаружен символ "{"
"}"             { return FCB; }       // Обнаружен символ "}"
";"             { return SEMICOLON; } // Обнаружена точка с запятой
[0-9]+          { yylval.i = atoi(yytext); return STEPS; } // Обнаружено целое число (шаги)
"left"          { return LEFT; }      // Обнаружено ключевое слово "left"
"right"         { return RIGHT; }     // Обнаружено ключевое слово "right"
"up"            { return UP; }        // Обнаружено ключевое слово "up"
"down"          { return DOWN; }      // Обнаружено ключевое слово "down"
"rock"      	{ return ROCK; }       // Обнаружено ключевое слово "rock"
"times"         { return TIMES; }     // Обнаружено ключевое слово "times"
"free"          { return FREE; }      // Обнаружено ключевое слово "free"
.              { fprintf(stderr, "Ошибка: неожиданный символ %s в строке %d\n", yytext, yylineno); exit(1); } // Обнаружен неожиданный символ
%%
