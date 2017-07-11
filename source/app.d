import std.stdio, std.path, std.algorithm, std.file, std.regex, std.string, std.conv, std.functional, std.range, std.process;
import core.stdc.stdlib;

void main( string[] args)
{
    // имя файла создаваемой программы
	string file;
	if ( args.length > 1 )
	  file = args[1];
	else  
	  file = ""; 
    // имя программы
    auto prgname = file.baseName.replace( regex(`\..+$`), "" );

	// найти шаблон
	string[] templates = dirEntries( args[0].dirName, SpanMode.breadth ).
	  filter!( f=>matchFirst( f.to!string , `.+\.tt`)).map!"a.to!string".array;
	  
	
	if ( templates.empty ){
	  auto home = environment.get("HOME","");
	  if ( !home.empty )
		templates = dirEntries( home, SpanMode.shallow ).
		  filter!( f=>matchFirst( f.to!string , `.+\.tt`)).map!"a.to!string".array;
	}
	
	string template_name;
	if (templates.empty){
	  template_name = args[0].dirName ~ "/d.tt";
	  std.file.write( template_name, template_single( prgname ) );
	}else  if (templates.length==1){
	  template_name = templates.front; 
	}else{
	  foreach ( tnum,tname; templates.enumerate(1) )
		writefln( "%d: %s", tnum, tname);
	  string answer;
	  int i;
	  while( ! matchFirst( answer, `^\d+$` ) || i<1 || i>templates.length ){
		writeln("Select template: (type number and press Enter)");
		answer = readln.strip;
		i = answer.to!int - 1;
	  }
	  template_name = templates[ i ];
	}

    // Если имя файла не указано
    if ( file.empty ){
  	  stderr.writefln( "Usage: %s <file.d>" , args[0].baseName ); 
  	  // installing
	  auto pathToMe = executeShell( "which " ~ args[0].baseName );
	  if ( pathToMe.output.empty )
		stderr.writeln("Please add me to PATH:\nexport PATH=$PATH:" , args[0].dirName );
		stderr.writeln("(If not already have, set env var EDITOR)");
		exit(1);
	}
  
	if ( !file.exists ) copy( template_name, file );
	
	// открыть файл в редакторе EDITOR
	auto editor = environment.get("EDITOR" , "");
	if (editor.empty){
	  stderr.writeln("Set env var EDITOR. f.e.: 'export EDITOR=mcedit'");
	  exit(1);
	}
	  
	auto editCmd = "%s %s".format( editor, file);
	//stderr.writeln( editCmd);
	auto edPid = spawnShell( editCmd );
	edPid.wait;
	//ed.output.write;
	//if (ed.status != 0) writeln("Error while call editor. Set EDITOR env variable.");

	bool isDubSingle;
	isDubSingle = !matchFirst( file.readText, regex(`^\s*dub.json:\s*\n`, "m")).empty;
	
	string cmd;
	if (isDubSingle)
  	  cmd = `dub build --single ` ~ file;
  	else
  	  cmd = "dmd " ~ file;
  	  
  	stderr.writeln( "Run " ~ cmd ~ " ... ");
    auto buildPid = spawnShell( cmd );
	buildPid.wait;	
		
}

string template_single( string prgname ){
return `/+
dub.json:
{
  "name": "` ~ prgname ~`"
}
+/
module ` ~ prgname ~`;
import std.stdio, std.getopt, std.string, std.regex,
	std.algorithm, std.array, std.conv, std.range, std.functional,
	std.file, std.path, std.process,
	std.format, std.csv, std.xml, std.zip, std.zlib, std.json,
	std.uri, std.uni,  std.utf,	std.ascii, std.base64,
    std.system, std.traits, std.typecons,
    std.datetime, std.demangle, std.digest.md, std.encoding, std.exception,
    std.bigint, std.bitmanip, std.compiler, std.complex, std.concurrency, std.container, 
    std.math, std.mathspecial, std.mmfile,
    std.numeric, std.outbuffer, std.parallelism, 
    std.random,  std.signals, std.socket,
    std.stdint, std.windows.syserror, 
    std.typetuple,  std.variant ;

void main()
{
  writefln("Ok");
}
`;
}