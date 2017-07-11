import std.stdio, std.path, std.algorithm, std.file, std.regex, std.string, std.conv, std.functional, std.range, std.process;

void main( string[] args)
{
    // имя файла создаваемой программы
	string f;
	if ( args.length > 1 )
	  f = args[1];
	else  
	  f = ""; 
    // имя программы
    auto prg = f.baseName.replace( regex(`\..+`), "" );

	// найти шаблон
	auto templates = dirEntries( args[0].dirName, SpanMode.breadth).filter!( f=>matchFirst( f.to!string , `.+\.tt`));
	string t;
	if (templates.empty){
	  t = args[0].dirName ~ "/d.tt";
	  std.file.write( t, template_single( f ) );
	}else  
	  t = templates.front; //

    // Если имя файла не указано, хотя это можно удалить:
    if ( f.empty ) f = t.replace(".tt", ".d").baseName;

  
	if ( !f.exists ) copy( t, f );
	
	// открыть файл в редакторе EDITOR
	auto editPid = spawnShell(`$EDITOR ` ~ f );
//	auto autoRerun = spawnShell( `auto-rebuild ` ~ f ~ ` "dub build --single "` ~ f );
	
	editPid.wait;
//	autoRerun.kill;
//	autoRerun.wait;

    auto cmd = `dub build --single ` ~ f;
    stderr.writeln( "Run " ~ cmd ~ " ... ");
    auto buildPid = spawnShell( cmd );
	buildPid.wait;
	
	// в фоне выполнять программу auto-rebuild файл "dub build --single файл"
}

string template_single( string prgname ){
return `/+
dub.json:
{
  "name": "` ~ prgname ~`"
}
+/
module ` ~ prgname ~`;
import std.stdio;

void main()
{
  writefln("Ok");
}
`;
}