/*
* Group Number : 05 
* E/17/176 Kumara W.M.E.S.K.
* E/17/090 Francis F.B.A.H 
*/
/*
 * The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

int comment_depth=0;

extern YYSTYPE cool_yylval;


%}

/*These three states are used to handle string constants*/
%x STRING
%x ESCAPE
%x SKIPSTR
/*This tates is used to handle multiline comments*/
%x COMMENT


SINGLELINECOMMENTS	(--.*)
MULTILINE_COMMENTS_BEGINING	\(\*
UNMATCHED	"*)"

WHITESPACE	[ \t\r\f\v]
NEWLINE		\n

CLASS		(?i:class) 
ELSE		(?i:else)   
FI 		(?i:fi)      
IF 		(?i:if)      
IN 		(?i:in)      
INHERITS 	(?i:inherits)
LET 		(?i:let)    
LOOP 		(?i:loop)  
POOL 		(?i:pool)  
THEN 		(?i:then)  
WHILE 		(?i:while)    
CASE 		(?i:case)  
ESAC 		(?i:esac)  
OF 		(?i:of)      
NEW 		(?i:new)    
ISVOID 		(?i:isvoid)  
NOT 		(?i:not)    
TRUE 		t(?i:rue)  
FALSE 		f(?i:alse) 



STRING_START	\"

OBJECTID	[a-z][a-zA-Z0-9_]*
TYPEID		[A-Z][a-zA-Z0-9_]*
INTEGER		[0-9]+

SYMBOLS		[\.\@\~\*\/\+\-\:\;\=\<\,\(\)\{\}]
DARROW         =>
ASSIGN		<-
LE		<=

ERROR		.


%%

 /*
  * comments
  * Multiline comments: any text surrounded with (*...*),
  * there might be nested comments.
  */

{MULTILINE_COMMENTS_BEGINING}	{comment_depth++ ; BEGIN(COMMENT);}
{UNMATCHED} {cool_yylval.error_msg="Unmatched *)"; return ERROR;}

<COMMENT>{
	<<EOF>>	{

			cool_yylval.error_msg="EOF in comment" ;
			BEGIN(INITIAL);
			return ERROR;

		}
	"(*"	{ comment_depth++; }
	"*)"	{ 
	          comment_depth-- ;
		  if(comment_depth==0){ BEGIN(INITIAL); }
		}
	\n	{ ++curr_lineno ; }
	.	{}
}

 /*
 *  Single line comments are start with -- 
 *  Singel line comments are neglected by below rule
 */
{SINGLELINECOMMENTS}	{}






 /*
	below are the rules for the keywords.
	They are not case sensitive.
	the regular expression (?i:PATTERN) matches the given pattern
	without considering the case.
	for each keyword corresponding token is returned.
 */
{CLASS} 	{return (CLASS);}
{ELSE}  	{return (ELSE);}
{FI}    	{return(FI);}
{IF}    	{return(IF);}
{IN}    	{return (IN); }
{INHERITS}  	{return(INHERITS);}
{LET}   	{return(LET);}
{LOOP}  	{return(LOOP);}
{POOL}  	{return(POOL);}
{THEN}  	{return(THEN);}
{WHILE} 	{return(WHILE);}
{CASE}  	{return(CASE);}
{ESAC}  	{return(ESAC);}
{OF}        	{return(OF);}
{NEW}   	{return(NEW);}
{ISVOID}    	{return(ISVOID);}
{NOT}   	{return(NOT);} 


 /*
	Below two rules are for keywords, true and false.
	for these two variables first letter must be a lowercase letter and
	the rest is case insensitive.
	the corresponding semantic value is stored in the symbol table
	and the appropriate token (BOOL_CONST) is returned in both cases. 
 */
{TRUE}  	{cool_yylval.boolean = true ; return( BOOL_CONST);}
{FALSE}     	{cool_yylval.boolean = false ;return( BOOL_CONST);}


 /*if newline found increment line number*/
{NEWLINE}	{curr_lineno++;}

 /*this rule will ignore the white spaces*/
{WHITESPACE}	{}


 /*
	Rules for match string constants
	________________________________

	When a " is found in the INITIAL state, it is a start of a string constant.
	The state STRING (defined at the definition section line:48) 
	is used to indicate that a start of a string constant was previously encountered.
	when a " is matched, the state is set to STRING	
	Also the string buffer is cleared to assemble the new string constant.
 */
	
{STRING_START}	{
		  strcpy(string_buf, "");
		  BEGIN(STRING);
		}

 /*
	There are few charachter which are not allowed in a string constant
		\x00 : the null char
		\n   : unescaped newline
		EOF  : end of file
	The three rules below are used to check whether the string contains these char's.
	If so an error message is stored and ERROR token is returened.
	After an error the rest of the string constant should be neglected.
	The state SKIPSTR (defined at the definition section line:50)
	is used to neglect the rest of the string constant.
	if an error occured, the state is set to SKIPSTR 
 */
<STRING>\x00	{
		     	cool_yylval.error_msg = "String contains null character";
		        BEGIN(SKIPSTR);
		        return (ERROR);
               	}

<STRING>\n      {
                 	curr_lineno++;
                        cool_yylval.error_msg = "Unterminated string constant";
                        BEGIN(INITIAL);
                        return (ERROR);
               	}

<STRING><<EOF>> {
                        cool_yylval.error_msg = "EOF in string constant";
                        BEGIN(INITIAL);
                        return (ERROR);
                }

 /*
	The rule below is for take actions for escaped characters.
	The state ESCAPE (defined at the definition section line:49)
	is used to take necessary actions according to the char followed by \
	When a \ is found the state is set to ESCAPE.
 */

<STRING>\\	{		
			BEGIN(ESCAPE);
		}

 /*
	If a " is found in STRING state, that means the end of the string constant is reached.
	The assembled string which is in the strig_buf is written to the symbol table and
	token STR_CONSt is returened.
 */
<STRING>\"      { 
                        cool_yylval.symbol = stringtable.add_string(string_buf);
                        BEGIN(INITIAL);
                        return (STR_CONST);
                }

 /*
	if a input is not containing char's that are not allowed and not containing \ or "
	that means it is a portion of the string constant.
	it is put into the string_buf to assemble entire string.
 */
<STRING>[^\\\"\x00\n<<EOF>>]+  {
                       		/*
					if the buffer is overflowing after adding new portion
					the string is too long.(Checked whether the length of the string
					after concatinating the new portion is smaller then the MAX_STR_CONST)
					The state is set to SKIPSTR and ERROR token is returened.
				*/
                        	if ((strlen(string_buf) + strlen(yytext)) >= MAX_STR_CONST) {
                          		cool_yylval.error_msg = "String constant too long";
                          		BEGIN(SKIPSTR);
                          		return (ERROR);
                        	}
                        	/*if not concatinate new portion with the current string*/
                        	strcat(string_buf, yytext);
                      	}
 /*
	The two rules below are to handle escaped charachters.
	They are only matched in ESCAPE state
	The first rule is for escaped newline.
	the current line number is incremented and \n is added to string buffer.
	Then returned to STRING state to read the rest of string constant.
 */

<ESCAPE>\n	{
		  	int len = strlen(string_buf);
                        /*
				check for buffer overflow, if so error is returened
				and state is set to SKIPSTR
			*/
                        if ((len + 1) >= MAX_STR_CONST) {
                          cool_yylval.error_msg = "String constant too long";
                          BEGIN(SKIPSTR);
                          return (ERROR);
                        }
                        string_buf[len] = '\n';
                        string_buf[len + 1] = '\0';
                        curr_lineno++;
			BEGIN(STRING);
		}

 /*
	this rule is to handle escaped characters except \n.
 */
<ESCAPE>.	{		
			int len = strlen(string_buf);
                        /*check for buffer overflows*/
                        if ((len + 1) >= MAX_STR_CONST) {
                          cool_yylval.error_msg = "String constant too long";
                          BEGIN(SKIPSTR);
                          return (ERROR);
                        }
                        
                        if (yytext[0] == 'b') { string_buf[len] = '\b'; } 	/*if the followed char is b \b is added to the buffer*/
			else if (yytext[0] == 't') { string_buf[len] = '\t'; } 	/*if the followed char is t \t is added to the buffer*/
			else if (yytext[0] == 'n') { string_buf[len] = '\n'; } 	/*if the followed char is n \n is added to the buffer*/
			else if (yytext[0] == 'f') { string_buf[len] = '\f'; } 	/*if the followed char is f \f is added to the buffer*/
			else { string_buf[len] = yytext[0]; }	/*for any other char, the char is added to the buffer*/
                        
			string_buf[len + 1] = '\0'; /*add string termination to buffer*/
			BEGIN(STRING);
		}

 /*
	Below three rules are used to neglect a string constant after a error.
	By first rule, when the end of string constant is reached the state is set to INITIAL
	to resume the lexing. (If " or an unescaped newline is found, that means end of the string
	constant is reached)
	In the second rule, if a escaped newline is found the current line number is incremented.
	In the third rule, the every char is discarded. 
*/
<SKIPSTR>([\"]|[^\\]\n) {curr_lineno++; BEGIN(INITIAL); }
<SKIPSTR>\\\n           {curr_lineno++;}
<SKIPSTR>.              {}

 /*
 	the following rule is for handle object ID's.
	Object ID is starting from a lowercase letter and
	rest can contain letters,numbers and _
	The regex is defined in definition area.
	The ID is stored in symbol table and corresponding token is returned
 */
{OBJECTID}	{ 
			cool_yylval.symbol = idtable.add_string(yytext,yyleng);
			return (OBJECTID);
		}

 /*
 	the following rule is for handle type ID's.
	Type ID is starting from a uppercase letter and
	rest can contain letters,numbers and _
	The regex is defined in definition area.
	The ID is stored in symbol table and corresponding token is returned
 */
{TYPEID}	{
			cool_yylval.symbol = idtable.add_string(yytext,yyleng);
			return (TYPEID);
		}
 /*
 	the following rule is for handle integers.
	The value is stored in symbol table and corresponding token is returned
 */
{INTEGER}	{
			cool_yylval.symbol = inttable.add_string(yytext,yyleng);
			return (INT_CONST);
		}
 /*
 	there are few symbols in cool language.
	+,-,(,) etc.
	the symbol is returened.
 */
{SYMBOLS}	{ return (yytext[0]);}

 /*
 	below three rules are for multi-charachter operators
		1. DARROW : =>
		2. ASSIGN : <-
		3. less than : <= 
 */
{DARROW}	{ return (DARROW); }
{ASSIGN}	{ return (ASSIGN);}
{LE}		{ return (LE);}


 /*
	Anything that does not match above rules is an error.
 */
{ERROR}		{ 
		 	cool_yylval.error_msg = yytext;
		  	return (ERROR);
		}

%%
