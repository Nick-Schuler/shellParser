%{
#include <stdio.h>
#include <stdarg.h>
#include "bash.h"

/* some internal files generated by bison */
int yylex();
void yyerror(const char *s,...);
void yywarn(const char *s,...);

// data structure to hold a linked list of arguments for a command
struct args {
    char *arg;
    struct args *next;
};

// data structure to hold a linked list of redirections for a command
struct redirs {
    int redir_token;
	char *filename;
    struct redirs *next;
};


/* include debugging code, in case we want it */
#define YYDEBUG 1

int lines = 1;
static int synerrors = 0;
int pipeNum;


%}


%union	{ /* the types that we use in the tokens */
    char *string;
    struct command *pcmd;
    struct args *pargs;
    struct redirs *predir;
    int number;
}



%token EOLN PIPE 
%token INFILE					// standard input redirection
%token OUTFILE OUTFILE_APPEND	// standard output redirection
%token ERRFILE ERRFILE_APPEND	// standard error redirection
%token <string> WORD

%type <pcmd> line cmd	// main datatype from bash.h
%type <pargs> optargs arg
%type <predir> optredirs redir
  

%% 	/* beginning of the parsing rules	*/
input	: lines
	|
  	;

lines	: oneline
	| oneline lines
	;

oneline : line
	  	eoln
		{	
			if(synerrors == 0){
				doline($1);
			}
			synerrors = 0;
		}
 	| eoln	/* blank line, do nothing */{
		synerrors = 0;
	}
	| error eoln
	/* if we got an error on the line, don't call the C program */
	;

eoln	: EOLN
		{ ++lines; }
	;


line	: cmd
		{
			// cmd is a datastructure, pass it upstream
			$$ = $1;
		}
  	| cmd PIPE line
		{
			// cmd and line are both datastructures, hook them together in a linked list
			struct command *c;

			c = (struct command *) malloc(sizeof(struct command));

			c = $1;

			//error catching
			if($3->infile != NULL){
				yyerror("illegal redirection");
			}
			if(c->outfile != NULL){
				yyerror("illegal redirection");
			}

			c->next = $3;
			c->outfile = "PIPE";
			$3->infile = "PIPE";

			$$ = c;
		}
  	;

// FINISH THIS
cmd	: WORD optargs optredirs
		{ 
			// make and fill node of type "struct command "
			// grab the linked list for optargs and install it in the structure
			// grab the linked list for optredir and install it in the structure

			struct command *c;

			c = (struct command *) malloc(sizeof(struct command));

			c->command = $1;
			c->argv[0] = $1;
			++c->argc;
			c->lines = lines;
			
			//args
			while($2){
				c->argv[c->argc] = $2->arg;
				++c->argc;
				$2 = $2->next;
			}
			
			while($3){

				//error catching
				if($3->next != NULL){
					if($3->redir_token == $3->next->redir_token){
						yyerror("illegal redirection");
					}
					else if($3->redir_token == 2 && $3->next->redir_token == 3){
						yyerror("illegal redirection");
					}
					else if($3->redir_token == 4 && $3->next->redir_token == 5){
						yyerror("illegal redirection");
					}
					if($3->next->next != NULL){
						if($3->redir_token == $3->next->next->redir_token){
							yyerror("illegal redirection");
						}
					}
				}

				//FILE REDIRS
				if($3->redir_token == 1){
					c->infile = $3->filename;
				}
				if($3->redir_token == 2){
					c->outfile = $3->filename;
				}
				if($3->redir_token == 3){
					c->outfile = $3->filename;
					c->output_append = 1;
				}
				if($3->redir_token == 4){
					c->errfile = $3->filename;
				}
				if($3->redir_token == 5){
					c->errfile = $3->filename;
					c->error_append = 1;
				}
				$3 = $3->next;
			}

			$$ = c;
		}
	;

// FINISH THIS
// these 2 rules are for "optional arguments".  They should allow one or more "arg"s
// and assemble them into a linked list of type "struct args" and return it upstream
optargs : arg optargs
			{ 
				$$ = (struct args *) malloc(sizeof(struct args));
				$$->arg = $1->arg;
				$$->next = $2;
			}
		|	
			{ $$ = NULL; // no more args 
			}
		;
arg		: WORD
		{
			// make a node for type "struct args" and pass it upstream
			$$ = (struct args *) malloc(sizeof(struct args));
			$$->arg = $1;
		}
		;

// these 2 rules are for "optional redirection".  They allow one or more sets of 
// redirection commands from the rule "redir"
// and assemble them into a linked list of type "struct redir" and return it upstream
optredirs : redir optredirs
			{ 	
				$$ = (struct redirs *) malloc(sizeof(struct redirs));
				$$->redir_token = $1->redir_token;
				$$->filename = $1->filename;
				$$->next = $2;
			}
		|
			{ $$ = NULL; // no more redirection 
			}
		;
				
redir	: INFILE WORD
		{ 
			struct redirs *r;
			r = (struct redirs *) malloc(sizeof(struct redirs));
			r->filename = $2;
			r->redir_token = 1;
			$$ = r;  // build a data structure of type struct redirs and pass it upstream
		}
		| OUTFILE WORD
		{
			struct redirs *r;
			r = (struct redirs *) malloc(sizeof(struct redirs));
			r->filename = $2;
			r->redir_token = 2;
			$$ = r;
		}
		| OUTFILE_APPEND WORD
		{
			struct redirs *r;
			r = (struct redirs *) malloc(sizeof(struct redirs));
			r->filename = $2;
			r->redir_token = 3;
			$$ = r;
		}
		| ERRFILE WORD
		{
			struct redirs *r;
			r = (struct redirs *) malloc(sizeof(struct redirs));
			r->filename = $2;
			r->redir_token = 4;
			$$ = r;
		}
		| ERRFILE_APPEND WORD
		{
			struct redirs *r;
			r = (struct redirs *) malloc(sizeof(struct redirs));
			r->filename = $2;
			r->redir_token = 5;
			$$ = r;
		}
		;

%%

void
yyerror(const char *error_string, ...)
{
    va_list ap;
    int line_nmb(void);

    FILE *f = stdout;

    va_start(ap,error_string);

    ++synerrors;

    fprintf(f,"Error on line %d: ", lines);
    vfprintf(f,error_string,ap);
    fprintf(f,"\n");
    va_end(ap);
}