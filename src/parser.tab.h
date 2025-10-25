/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_SRC_PARSER_TAB_H_INCLUDED
# define YY_YY_SRC_PARSER_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 1
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    TK_INT = 258,                  /* TK_INT  */
    TK_BOOL = 259,                 /* TK_BOOL  */
    TK_IF = 260,                   /* TK_IF  */
    TK_ELSE = 261,                 /* TK_ELSE  */
    TK_WHILE = 262,                /* TK_WHILE  */
    TK_PRINT = 263,                /* TK_PRINT  */
    TK_READ = 264,                 /* TK_READ  */
    TK_TRUE = 265,                 /* TK_TRUE  */
    TK_FALSE = 266,                /* TK_FALSE  */
    TK_SEMICOLON = 267,            /* TK_SEMICOLON  */
    TK_COMMA = 268,                /* TK_COMMA  */
    TK_LPAREN = 269,               /* TK_LPAREN  */
    TK_RPAREN = 270,               /* TK_RPAREN  */
    TK_LBRACE = 271,               /* TK_LBRACE  */
    TK_RBRACE = 272,               /* TK_RBRACE  */
    TK_INTEGER = 273,              /* TK_INTEGER  */
    TK_ID = 274,                   /* TK_ID  */
    TK_EQ = 275,                   /* TK_EQ  */
    TK_NE = 276,                   /* TK_NE  */
    TK_LE = 277,                   /* TK_LE  */
    TK_GE = 278,                   /* TK_GE  */
    TK_LT = 279,                   /* TK_LT  */
    TK_GT = 280,                   /* TK_GT  */
    TK_LOGICAL_AND = 281,          /* TK_LOGICAL_AND  */
    TK_LOGICAL_OR = 282,           /* TK_LOGICAL_OR  */
    TK_LOGICAL_NOT = 283,          /* TK_LOGICAL_NOT  */
    TK_PLUS = 284,                 /* TK_PLUS  */
    TK_MINUS = 285,                /* TK_MINUS  */
    TK_MULT = 286,                 /* TK_MULT  */
    TK_DIV = 287,                  /* TK_DIV  */
    TK_MOD = 288,                  /* TK_MOD  */
    TK_ASSIGN = 289,               /* TK_ASSIGN  */
    UMINUS = 290                   /* UMINUS  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef int YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);


#endif /* !YY_YY_SRC_PARSER_TAB_H_INCLUDED  */
