%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "RobotControl.tab.h"

#define n 2 // количество столбцов в двумерном массиве и ячеек в одномерном массиве

// Объявление функции лексического анализатора
int yylex();

// Функция yywrap - оборачивание лексера, возвращает 1 для указания конца ввода
char yywrap() {
    return 1;
}

// Внешняя переменная для отслеживания номера текущей строки в исходном коде
extern int yylineno;

// Функция обработки ошибок, принимает строку с сообщением об ошибке
void yyerror(char *str);

// Внешние переменные для управления входным и выходным потоками лексера/парсера
extern FILE* yyin;
extern FILE* yyout;

// счетчик всех действий и перемещений робота
int counter;

// координаты робота
int robot[n];

// координаты камней
int numberOfRowsFir;
int *rock;

// флаг крутых камней
int *makeUpedRock;

// чтение файла окружения
void readEnvironmentFile(FILE* enviromentFile);

// Структура для узлов в абстрактном синтаксическом дереве (AST)
struct ast {
    int nodetype;      // Тип узла в дереве
    struct ast *l;     // Левое поддерево
    struct ast *r;     // Правое поддерево
};

// Структура для узлов, представляющих числовые значения в AST
struct numval {
    int nodetype;      // Тип K (число)
    int number;        // Значение числа
};

// Структура для узлов, представляющих управляющие конструкции (if или while) в AST
struct flow {
    int nodetype;      // Тип I (if)
    struct ast *cond;  // Условие
    struct ast *tl;    // Тогда или список действий
    struct ast *el;    // Необязательный список иначе (else)
};

// построение AST
struct ast *newAst(int nodetype, struct ast *l, struct ast *r);
struct ast *newNum(int i);
struct ast *newFlow(int nodetype, struct ast *cond, struct ast *tl, struct ast *el);

// оценка AST
int evaluate(struct ast *);

// оценка перемещений
void evaluateMovements(int value, int checkDirection);

// оценка действий
void evalActions(int checkAction, int checkDirection);

// проверка наличия объектов вокруг
int defineEnvironment(int helperArray[], int checkDirection, int flag);

// перезапись массива
void overwriteArray(int helperArray[], int *array, int sizeArray, int flag);

// удаление и освобождение AST
void freeAstTree(struct ast *);

%}

%union{
    struct ast *a;
    int i;
}

%token <i> STEPS
%token LEFT RIGHT UP DOWN ROCK TIMES FREE DES M D
%token IF ELSE WHILE OB CB FOB FCB SEMICOLON

%type <a> body condition elsee statement direction action steps 

%%

commands:
| commands body { evaluate($2); freeAstTree($2); }
;

body: IF OB condition CB FOB body FCB elsee { $$ = newFlow('I', $3, $6, $8); }
| IF OB condition CB FOB body FCB { $$ = newFlow('I', $3, $6, NULL); }
| WHILE OB condition CB FOB body FCB { $$ = newFlow('W', $3, $6, NULL); }
| statement SEMICOLON { $$ = newAst('s', $1, NULL); }
;

elsee: ELSE FOB body FCB { $$ = newAst('e', $3, NULL); }
;

condition: direction FREE { $$ = newAst('F', $1, NULL); }
;

statement: direction steps TIMES { $$ = newAst('T', $1, $2); }
| action ROCK direction { $$ = newAst('a', $1, $3); }
;

direction: UP { $$ = newAst('u', NULL, NULL); }
| DOWN { $$ = newAst('d', NULL, NULL); }
| LEFT { $$ = newAst('l', NULL, NULL); }
| RIGHT { $$ = newAst('r', NULL, NULL); }
;

action: DES { $$ = newAst('DES', NULL, NULL); }
| M { $$ = newAst('M', NULL, NULL); }
| D { $$ = newAst('D', NULL, NULL); }
;

steps: STEPS { $$ = newNum($1); }
;

%%

void yyerror(char *str){
    fprintf(yyout ,"%d. Ошибка: %s в строке %d\n", counter, str, yylineno);
    exit(1);
}

int main() {
    char *programmFileName = "programm.txt";
    FILE* programmFile = fopen(programmFileName, "r");

    // Проверка успешного открытия файла программы
    if (programmFile == NULL) {
        fprintf(yyout, "%d. Невозможно открыть файл %s", counter, programmFileName);
        exit(1);
    }

    char *enviromentFileName = "enviroment.txt";
    FILE* enviromentFile = fopen(enviromentFileName, "r");

    // Проверка успешного открытия файла окружения
    if (enviromentFile == NULL) {
        fprintf(yyout, "%d. Невозможно открыть файл %s", counter, enviromentFileName);
        exit(1);
    }

    char *logFileName = "res.txt";
    FILE* logFile = fopen(logFileName, "w");

    // Настройка ввода и вывода для анализатора
    yyin = programmFile;
    yyout = logFile;

    // Чтение файла окружения
    readEnvironmentFile(enviromentFile);

    // Инициализация массива makeUpedRock
    // 0 - не Крутой камень, 1 - Крутой камень
    makeUpedRock = (int*) malloc(numberOfRowsFir * sizeof(int));
    for (int i = 0; i < numberOfRowsFir; i++) {
        *(makeUpedRock + i) = 0;
    }

    // Начало синтаксического анализа
    yyparse();

    // Закрытие файлов
    fclose(yyin);
    fclose(enviromentFile);
    fclose(yyout);

    // Освобождение выделенной памяти
    free(rock);
    free(makeUpedRock);

    return 0;
}

// Функция чтения данных из файла окружения
void readEnvironmentFile(FILE* enviromentFile){
    int numberOfRows = 0; // Переменная для подсчета строк в файле
    fseek(enviromentFile, 0, SEEK_SET); // Устанавливаем указатель файла в начало
    while (!feof(enviromentFile)){
        if (fgetc(enviromentFile) == '\n'){
            numberOfRows++; // Подсчитываем строки в файле
        }
    }
    numberOfRowsFir = numberOfRows - 2; // Количество строк для массива rock (за исключением строки с "robot" и строки с размерами)
    rock = (int*) malloc(numberOfRowsFir * n * sizeof(int)); // Выделяем память под массив rock

    char *bufferName; // Буфер для имени объекта (robot, rock)
    fseek(enviromentFile, 0, SEEK_SET); // Устанавливаем указатель файла в начало
    while (!feof(enviromentFile)){
        fscanf(enviromentFile, "%s", bufferName); // Считываем имя объекта из файла
        char *robotName = "robot";
        if (strcmp(bufferName, robotName) == 0){ // Если объект - робот
            for (int i = 0; i < n; i++){
                fscanf(enviromentFile, "%d,", &robot[i]); // Считываем координаты робота
            }
        }
        else{
            for (int i = 0; i < numberOfRowsFir; i++){
                for (int j = 0; j < n; j++){
                    fscanf(enviromentFile, "%d,", (rock + i * n + j)); // Считываем данные о rock
                }
            }
        }
    }     
}

// Создание нового узла AST с указанным типом и дочерними узлами
struct ast *newAst(int nodetype, struct ast *l, struct ast *r){
    struct ast *a = malloc(sizeof(struct ast));

    if (!a){
        yyerror("Оut of space, robot go away");
        exit(0);
    }
    a->nodetype = nodetype;
    a->l = l;
    a->r = r;
    return a;
}

// Создание нового узла AST с числовым значением
struct ast *newNum(int i){
    struct numval *a = malloc(sizeof(struct numval));

    if (!a){
        yyerror("Оut of space, robot go away");
        exit(0);
    }
    a->nodetype = 'K';
    a->number = i;
    return (struct ast *)a;
}

// Создание нового узла AST для оператора IF с условием, true-веткой и false-веткой
struct ast *newFlow(int nodetype, struct ast *cond, struct ast *tl, struct ast *el){
    struct flow *a = malloc(sizeof(struct flow));

    if(!a) {
        yyerror("Оut of space, robot go away");
        exit(0);
    }
    a->nodetype = nodetype;
    a->cond = cond;
    a->tl = tl;
    a->el = el;
    return (struct ast *)a;
}

/* Типы узлов:
 *  s statement (оператор)
 *  e else (иначе)
 *  F direction free (свободное направление)
 *  T direction step TIMES (направление и шаг во времени)
 *  a action ROCK (действие - Залить краской камень, сделать его крутым)
 *  u up (вверх)
 *  d down (вниз)
 *  l left (влево)
 *  r right (вправо)
 *  DES destroy (разнести)
 *  M makeup(сделать крутым)
 *  D drop rock (дропнуть камень)
 *  I IF statement (условный оператор)
 *  W WHILE statement
 */ 

int evaluate(struct ast *a){
    // Значение, возвращаемое функцией
    int value;

    // Переменные для проверки направления и действия
    int checkDirection;
    int checkAction;

    // Флаг для оценки окружения (для использования в функции defineEnvironment)
    int flag = -2;

    // Вспомогательный массив для оценки окружения
    int helperArray[n];

    // Определяем тип узла AST и выполняем соответствующие действия
    switch(a->nodetype){
        case 'K': 
            value = ((struct numval *)a)->number; // просто число
            break;
        case 's':
            evaluate(a->l); // оператор (statement) - выполняем его
            break;
        case 'e':
            evaluate(a->l); // иначе (else) - выполняем его
            break;
        case 'T':
            counter++;
            value = evaluate(a->r); // значение шага по времени
            checkDirection = evaluate(a->l); // оценка направления
            evaluateMovements(value, checkDirection); // выполнение движения в заданном направлении
            break;
        case 'a':
            counter++;
            checkAction = evaluate(a->l); // оценка действия
            checkDirection = evaluate(a->r); // оценка направления
            evalActions(checkAction, checkDirection); // выполнение действия в заданном направлении
            break;
        case 'DES':
            value = 'DES'; // снести
            break;
        case 'M':
            value = 'M'; // сделать крутым
            break;
        case 'D':
            value = 'D'; // дропнуть камень
            break;
        case 'F':
            checkDirection = evaluate(a->l); // оценка направления
            value = defineEnvironment(helperArray, checkDirection, flag); // оценка окружения в заданном направлении
            break;    
        case 'u':
            value = 0; // вверх
            break;
        case 'd':          
            value = 1; // вниз
            break;                 
        case 'r':
            value = 2; // вправо
            break;     
        case 'l':
            value = 3; // влево
            break; 
        case 'I':
            if(evaluate(((struct flow *)a)->cond) == 0) { // проверка условия - ветка true
                if(((struct flow *)a)->tl) {
                    evaluate(((struct flow *)a)->tl); // выполнение true-ветки
                } 
                else{
                    value = -1; // значение по умолчанию
                }
            }
            else { // ветка false
                if(((struct flow *)a)->el) {
                    evaluate(((struct flow *)a)->el); // выполнение false-ветки
                } 
                else {
                    value = -1; // значение по умолчанию
                }       
            }
            break;
        case 'W':
            value = -1; // значение по умолчанию

            if(((struct flow *)a)->tl) {
                while(evaluate(((struct flow *)a)->cond) == 0){
                    evaluate(((struct flow *)a)->tl); // last value is value
                }
            }
            break;
    }
    return value; // возвращаем значение
}

// Функция evaluateMovements оценивает перемещения робота в заданном направлении и на определенное расстояние.
void evaluateMovements(int value, int checkDirection){
    // Для корректного указания позиции при отображении ошибки, создаем временный массив для хранения текущих координат робота.
    int tempRobot[2];
    for(int i = 0; i < n; i++){
        tempRobot[i] = robot[i];
    }

    // Создаем вспомогательный массив для оценки окружения робота.
    int helperArray[n];
    
    // Флаг -1 используется для оценки, есть ли камень вокруг робота.
    int flag = -1;

    // Перемещаем робота на заданное расстояние в выбранном направлении.
    for(int i = 0; i < value; i++){
        switch(defineEnvironment(helperArray, checkDirection, flag)){
            // Если вокруг робота есть камень, генерируем ошибку и завершаем программу.
            case 1: 
                if(checkDirection == 0){ // вверх
                    fprintf(yyout, "%d. Ошибка: робот не могет переехать в точку (%d,%d) из-за камня в точке (%d,%d)\n", counter, tempRobot[0], tempRobot[1] + value, helperArray[0], helperArray[1]);
                    exit(1);
                }
                if(checkDirection == 1){ // вниз
                    fprintf(yyout, "%d. Ошибка: робот не могет переехать в точку (%d,%d) из-за камня в точке (%d,%d)\n", counter, tempRobot[0], tempRobot[1] - value, helperArray[0], helperArray[1]);
                    exit(1);
                }
                if(checkDirection == 2){ // вправо
                    fprintf(yyout, "%d. Ошибка: робот не могет переехать в точку (%d,%d) из-за камня в точке (%d,%d)\n", counter, tempRobot[0] + value, tempRobot[1], helperArray[0], helperArray[1]);
                    exit(1);
                }
                if(checkDirection == 3){ // влево
                    fprintf(yyout, "%d. Ошибка: робот не могет переехать в точку (%d,%d) из-за камня в точке (%d,%d)\n", counter, tempRobot[0] - value, tempRobot[1], helperArray[0], helperArray[1]);
                    exit(1);
                }
                break;

            // Если вокруг робота нет ели, перемещаем его в выбранном направлении.
            case 0: 
                if(checkDirection == 0){ // вверх
                    robot[1] += 1;
                }
                if(checkDirection == 1){ // вниз
                    robot[1] -= 1;
                }
                if(checkDirection == 2){ // вправо
                    robot[0] += 1;
                }
                if(checkDirection == 3){ // влево
                    robot[0] -= 1;
                }
                break;
        }
    }

    // Выводим сообщение о том, что робот переместился в новую позицию.
    fprintf(yyout, "%d. Робот переехал в точку (%d,%d)\n", counter, robot[0], robot[1]);
}

void evalActions(int checkAction, int checkDirection){
    // строка для удаления или добавления в defineEnvironment
    int helperArray[n];

    // для указания случая 'DES' или 'M' или 'D'
    int flag;

    switch(checkAction){
        case 'DES': // разнести камень, фактически, строка удаляется из массива
            flag = 0;
            if(defineEnvironment(helperArray, checkDirection, flag) == 0){
                fprintf(yyout, "%d, Ошибкааа: вы пытаетесь разнести камень, которого нет в точке (%d,%d)\n", counter, helperArray[0], helperArray[1]);
                exit(1);
            }
            overwriteArray(helperArray, rock, numberOfRowsFir, flag);
            fprintf(yyout, "%d. Робот разнес камень в точке (%d,%d)\n", counter, helperArray[0], helperArray[1]);
            break;
        case 'M': // разукрасить камень, 0 заменяется на 1 в массиве makeUpedRock
            flag = 1;
            if(defineEnvironment(helperArray, checkDirection, flag) == 0){
                fprintf(yyout, "%d. Ошибкааа: вы пытаетесь сделать камень крутым, которого нет в точке (%d,%d)\n", counter, helperArray[0], helperArray[1]);
                exit(1);
            }
            if(defineEnvironment(helperArray, checkDirection, flag) == 2){
                fprintf(yyout, "%d. Камень уже крутой в точке (%d,%d)\n", counter, helperArray[0], helperArray[1]);
            }
            else{
                overwriteArray(helperArray, rock, numberOfRowsFir, flag);
                fprintf(yyout, "%d. Робот разукрасил камень (сделал его крутым) в точке(%d,%d)\n", counter, helperArray[0], helperArray[1]);
            }
            break;
        case 'D': // дропнуть камень, новые координаты камня в массиве rock
            flag = 2;
            if(defineEnvironment(helperArray, checkDirection, flag) == 1){
                fprintf(yyout, "%d. Ошибкааа: в точке (%d,%d) уже есть камень (булыжник)\n", counter, helperArray[0], helperArray[1]);
                exit(1);
            }
            overwriteArray(helperArray, rock, numberOfRowsFir, flag);
            fprintf(yyout, "%d. Робот дропнул камень в точке (%d,%d)\n", counter, helperArray[0], helperArray[1]);
            break;
    }
}

// Функция определения окружения по направлению и координатам робота
// Возвращает:
//   0 - если в окружении нет камня
//   1 - если в окружении есть камень
//   2 - если робот столкнулся с с камнем и прекратил выполнение цикла
int defineEnvironment(int helperArray[], int checkDirection, int flag) {
    for(int k = 0; k < numberOfRowsFir; k++) {
        // Координаты текущего камня
        int xFir = *(rock + k * n + 0);
        int yFir = *(rock + k * n + 1);

        switch(checkDirection) {
            // Проверка направления вверх
            case 0:
                if (robot[0] == xFir && robot[1] + 1 == yFir) {
                    helperArray[0] = xFir;
                    helperArray[1] = yFir;
                    // Проверка флага и статуса ели
                    if(flag == 1 && *(makeUpedRock + k) == 1) {
                        return 2; // Робот столкнулся с камнем и прекратил выполнение цикла
                    }
                    return 1; // В окружении есть камень
                } else {
                    helperArray[0] = robot[0];
                    helperArray[1] = robot[1] + 1;
                }
                break;
            // Проверка направления вниз
            case 1:
                if(robot[0] == xFir && robot[1] - 1 == yFir) {
                    helperArray[0] = xFir;
                    helperArray[1] = yFir;
                    if(flag == 1 && *(makeUpedRock + k) == 1) {
                        return 2;
                    }
                    return 1;
                } else {
                    helperArray[0] = robot[0];
                    helperArray[1] = robot[1] - 1;
                }
                break;
            // Проверка направления вправо
            case 2:
                if(robot[0] + 1 == xFir && robot[1] == yFir) {
                    helperArray[0] = xFir;
                    helperArray[1] = yFir;
                    if(flag == 1 && *(makeUpedRock + k) == 1) {
                        return 2;
                    }
                    return 1;
                } else {
                    helperArray[0] = robot[0] + 1;
                    helperArray[1] = robot[1];
                }
                break;
            // Проверка направления влево
            case 3:
                if(robot[0] - 1 == xFir && robot[1] == yFir ) {
                    helperArray[0] = xFir;
                    helperArray[1] = yFir;
                    if(flag == 1 && *(makeUpedRock + k) == 1) {
                        return 2;
                    }
                    return 1;
                } else {
                    helperArray[0] = robot[0] - 1;
                    helperArray[1] = robot[1];
                }
                break;
        }
    }
    return 0; // В окружении нет камня
}

// Функция перезаписи массива с удалением элемента или обновлением флага
void overwriteArray(int helperArray[], int *array, int sizeArray, int flag) {
    int xArray, yArray;
    int *tempArray = NULL;
    tempArray = (int*) realloc(tempArray, sizeArray * n * sizeof(int));
    int *tempXMasFir = NULL;
    tempXMasFir = (int*) realloc(tempXMasFir, sizeArray * sizeof(int));
    int j = 0; // Нумерация для новых координат ели

    if(flag == 0) { // Удаление элемента из массива
        for(int i = 0; i < sizeArray; i++) {
            // Координаты камня
            xArray = *(array + i * n + 0);
            yArray = *(array + i * n + 1);
            if (helperArray[0] != xArray || helperArray[1] != yArray) {
                *(tempArray + j * n + 0) = xArray;
                *(tempArray + j * n + 1) = yArray;
                j++;
                *(tempXMasFir + j) = *(makeUpedRock + i);
            }
        }

        free(rock);
        numberOfRowsFir -= 1;
        rock = tempArray;

        free(makeUpedRock);
        makeUpedRock = tempXMasFir;
    }
    if(flag == 1) { // Обновление флага камня
        for(int i = 0; i < sizeArray; i++) {
            xArray = *(array + i * n + 0);
            yArray = *(array + i * n + 1);
            if(helperArray[0] == xArray && helperArray[1] == yArray) {
                *(makeUpedRock + i) = 1;
            }
        }
    }
    if(flag == 2) { // Добавление нового элемента в массив
        numberOfRowsFir += 1;
        rock = (int*) realloc(rock, numberOfRowsFir * n * sizeof(int));
        *(rock + (numberOfRowsFir - 1) * n + 0) = helperArray[0];
        *(rock + (numberOfRowsFir - 1) * n + 1) = helperArray[1];

        makeUpedRock = (int*) realloc(makeUpedRock, numberOfRowsFir * sizeof(int));
        *(makeUpedRock + numberOfRowsFir -1) = 0;
    }
}

/*
 * Типы узлов в AST:
 * 'T': Узел, представляющий оператор с шагами во времени.
 * 'a': Узел, представляющий действие.
 * 's': Узел, представляющий оператор (statement).
 * 'e': Узел, представляющий ветвь "иначе" (else).
 * 'F': Узел, представляющий свободное направление (free direction).
 * 'K': Узел, представляющий числовое значение (число).
 * 'u': Узел, представляющий движение вверх.
 * 'd': Узел, представляющий движение вниз.
 * 'l': Узел, представляющий движение влево.
 * 'r': Узел, представляющий движение вправо.
 * 'D': Узел, представляющий действие.
 * 'M': Узел, представляющий действие.
 * 'DES': Узел, представляющий действие.
 * 'I': Узел, представляющий условный оператор "if".
 */
 
// Освобождение памяти занятой AST
void freeAstTree(struct ast *a) {
    switch(a->nodetype) {
        // Два поддерева
        case 'T':
        case 'a':
            freeAstTree(a->r);

        // Одно поддерево
        case 's':
        case 'e':
        case 'F':
            freeAstTree(a->l);

        // Нет поддеревьев
        case 'K':
        case 'u':
        case 'd':
        case 'l':
        case 'r':
        case 'D':
        case 'M':
        case 'DES':
        break;

        // Условие и цикл
        case 'I':
        break;
        case 'W':
            free( ((struct flow *)a)->cond);
            if( ((struct flow *)a)->tl) free( ((struct flow *)a)->tl);
            if( ((struct flow *)a)->el) free( ((struct flow *)a)->el);
            break;
        default: fprintf(yyout, "%d. Внутренняя ошибкааа: освобождение некорректного узла %c\n", counter, a->nodetype);
    }
}
