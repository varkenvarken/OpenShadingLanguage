/** Parser for OpenShadingLanguage 'object' files
 **/

/*****************************************************************************
 *
 *             Copyright (c) 2009 Sony Pictures Imageworks, Inc.
 *                            All rights reserved.
 *
 *  This material contains the confidential and proprietary information
 *  of Sony Pictures Imageworks, Inc. and may not be disclosed, copied or
 *  duplicated in any form, electronic or hardcopy, in whole or in part,
 *  without the express prior written consent of Sony Pictures Imageworks,
 *  Inc. This copyright notice does not imply publication.
 *
 *****************************************************************************/


%{

// C++ declarations

#include <iostream>
#include <cstdlib>
#include <vector>
#include <string>

#include "osoreader.h"

#undef yylex
#define yyFlexLexer osoFlexLexer
#include "FlexLexer.h"

using namespace OSL;
using namespace OSL::pvt;

void yyerror (const char *err);

#define yylex OSOReader::osolexer->yylex
#define reader OSOReader::reader

static TypeSpec current_typespec;



// Convert from the lexer's symbolic type (COLORTYPE, etc.) to a TypeDesc.
inline TypeDesc
lextype (int lex)
{
    switch (lex) {
    case COLORTYPE  : return TypeDesc::TypeColor;
    case FLOATTYPE  : return TypeDesc::TypeFloat;
    case INTTYPE    : return TypeDesc::TypeInt;
    case MATRIXTYPE : return TypeDesc::TypeMatrix;
    case NORMALTYPE : return TypeDesc::TypeNormal;
    case POINTTYPE  : return TypeDesc::TypePoint;
    case STRINGTYPE : return TypeDesc::TypeString;
    case VECTORTYPE : return TypeDesc::TypeVector;
    case VOIDTYPE   : return TypeDesc::NONE;
    default: return PT_UNKNOWN;
    }
}


%}


// This is the definition for the union that defines YYSTYPE
%union
{
    int         i;  // For integer falues
    float       f;  // For float values
    const char *s;  // For string values -- guaranteed to be a ustring.c_str()
}


// Tell Bison to track locations for improved error messages
%locations


// Define the terminal symbols.
%token <s> IDENTIFIER STRING_LITERAL HINT
%token <i> INT_LITERAL
%token <f> FLOAT_LITERAL
%token <i> COLORTYPE FLOATTYPE INTTYPE MATRIXTYPE 
%token <i> NORMALTYPE POINTTYPE STRINGTYPE VECTORTYPE VOIDTYPE CLOSURE STRUCT
%token <i> CODE SYMTYPE ENDOFLINE

// Define the nonterminals 
%type <i> oso_file version shader_declaration
%type <s> shader_type
%type <i> symbols_opt symbols symbol typespec simple_typename arraylen_opt
%type <i> initial_values_opt initial_values initial_value
%type <i> codemarker label
%type <i> instructions instruction
%type <s> opcode
%type <i> arguments_opt arguments argument
%type <i> jumptargets_opt jumptargets jumptarget
%type <i> hints_opt hints hint

// Define the starting nonterminal
%start oso_file


%%

oso_file
        : version shader_declaration symbols_opt codemarker instructions
                {
                    $$ = 0;
                }
	;

version
        : IDENTIFIER FLOAT_LITERAL ENDOFLINE
                {
                    OSOReader::osoreader->version ($1, $2);
                    $$ = 0;
                }
        ;

shader_declaration
        : shader_type IDENTIFIER 
                {
                    OSOReader::osoreader->shader ($1, $2);
                }
            hints_opt ENDOFLINE
                {
                    $$ = 0;
                }
        ;

symbols_opt
        : symbols                       { $$ = 0; }
        | /* empty */                   { $$ = 0; }
        ;

codemarker
        : CODE IDENTIFIER ENDOFLINE
                {
                    OSOReader::osoreader->codemarker ($2);
                }
        ;

instructions
        : instruction
        | instructions instruction
        ;

instruction
        : label opcode 
                {
                    OSOReader::osoreader->instruction ($1, $2);
                }
            arguments_opt jumptargets_opt hints_opt ENDOFLINE
                {
                    OSOReader::osoreader->instruction_end ();
                }
        | codemarker
        | ENDOFLINE
        ;

shader_type
        : IDENTIFIER
        ;

symbols
        : symbol
        | symbols symbol
        ;

symbol
        : SYMTYPE typespec IDENTIFIER arraylen_opt
                {
                    TypeSpec typespec = current_typespec;
                    if ($4)
                        typespec.make_array ($4);
                    OSOReader::osoreader->symbol ((SymType)$1, typespec, $3);
                }
            initial_values_opt hints_opt ENDOFLINE
        | ENDOFLINE
        ;

/* typespec operates by merely setting the current_typespec */
typespec
        : simple_typename
                {
                    current_typespec = lextype ($1);
                    $$ = 0;
                }
        | CLOSURE simple_typename
                {
                    current_typespec = TypeSpec (lextype ($2), true);
                    $$ = 0;
                }
        | STRUCT IDENTIFIER /* struct name */
                {
                    // FIXME
                    $$ = 0;
                }
        ;

simple_typename
        : COLORTYPE
        | FLOATTYPE
        | INTTYPE
        | MATRIXTYPE
        | NORMALTYPE
        | POINTTYPE
        | STRINGTYPE
        | VECTORTYPE
        | VOIDTYPE
        ;

arraylen_opt
        : '[' INT_LITERAL ']'           { $$ = $2; }
        | /* empty */                   { $$ = 0; }
        ;

initial_values_opt
        : initial_values
        | /* empty */                   { $$ = 0; }
        ;

initial_values
        : initial_value
        | initial_values initial_value
        ;

initial_value
        : FLOAT_LITERAL
                {
                    OSOReader::osoreader->symdefault ($1);
                    $$ = 0;
                }
        | INT_LITERAL
                {
                    OSOReader::osoreader->symdefault ($1);
                    $$ = 0;
                }
        | STRING_LITERAL
                {
                    OSOReader::osoreader->symdefault ($1);
                    $$ = 0;
                }
        ;

label
        : INT_LITERAL ':'
        | /* empty */                   { $$ = -1; }
        ;

opcode
        : IDENTIFIER
        ;

arguments_opt
        : arguments
        | /* empty */                   { $$ = 0; }
        ;

arguments
        : argument
        | arguments argument
        ;

argument
        : IDENTIFIER
                {
                    OSOReader::osoreader->instruction_arg ($1);
                }
        ;

jumptargets_opt
        : jumptargets
        | /* empty */                   { $$ = 0; }
        ;

jumptargets
        : jumptarget
        | jumptargets jumptarget
        ;

jumptarget
        : INT_LITERAL
                {
                    OSOReader::osoreader->instruction_jump ($1);
                }
        ;

hints_opt
        : hints
        | /* empty */                   { $$ = 0; }
        ;

hints
        : hint
        | hints hint
        ;

hint
        : HINT
                {
                    OSOReader::osoreader->hint ($1);
                }
        ;

%%



void
yyerror (const char *err)
{
//    oslcompiler->error (oslcompiler->filename(), oslcompiler->lineno(),
//                        "Syntax error: %s", err);
    fprintf (stderr, "Error, line %d: %s", 
             OSOReader::osolexer->lineno(), err);
}


