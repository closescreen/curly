import std.stdio, std.path, std.algorithm, std.file, std.regex, std.string, std.array, std.conv, std.functional, std.range, std.process;
import core.stdc.stdlib, std.exception;

void main( string[] args)
{
    // имя файла создаваемой программы
	auto file = args.length > 1 ? args[1] : "";

   // Если имя файла программы *.d не указано
    if ( file.empty ){
      //usage instruction:
      stderr.writefln( "Usage: %s <file.d>" , args[0].baseName );

      // installing PATH instructions:
      executeShell( "which " ~ args[0].baseName ).output.empty &&
        stderr.writefln("Please add me to PATH:\nexport PATH=$PATH:%s" , args[0].dirName );

      exit(1);
    }

    // расширение файла
    string file_ex = file.extension.enforce.ifThrown("").replaceFirst(regex(`.`),"");


    // имя программы
    auto prgname = file.baseName.replace( regex(`\..+$`), "" );

	// найти/создать setting dir
	auto home = environment.get("HOME","");
	auto settings_dir = home.empty ? "" : buildPath( home, ".curly");
	if ( !settings_dir.exists ){
	  settings_dir.mkdir;
	  stderr.writefln("%s was created.", settings_dir);
	}

	if ( !file.exists ){

	
	  // найти/создать шаблон[ы]
	  string[] templates = dirEntries( thisExePath().dirName, SpanMode.shallow ).
	      filter!( f=>matchFirst( f.to!string , `.+\.tt`)).map!"a.to!string".array;

	  // имя файла шаблона, с которым работаем
	  string template_file_name;
	  
	  auto empty_name="Empty file";

	  if ( templates.empty ){
		template_file_name = empty_name;
	  }else  if (templates.length==1){
	    template_file_name = templates.front;
	  }else{
	    // если шаблонов несколько просим пользователя выбрать шаблон
	    template_file_name = userChoice("Select template", templates ~ empty_name );
	  }

	  auto prgText = template_file_name.exists ? 
		  template_file_name.readText.replaceAll( regex( r"\%prgname\%" ), prgname ) : 
		  "";

	  std.file.write( file, prgText );
	
	} // - end of if !file.exists
	
	// какой editor
	auto editor = environment.get("CURLY_EDITOR" , "");
	if ( editor==args[0].baseName ){
	  stderr.writefln("Not allowed %s as CURLY_EDITOR", editor);
	  exit(1);
	}else if( editor.empty ){  
	  editor = environment.get("EDITOR" , "");
	} 
	if (editor.empty){
	  auto editors_file = buildPath( settings_dir, ".editors.conf");
	  editor = userChoice("Choice editor", available_editors.array ~ listFromFile( editors_file) );
	  
	  if ( !empty(editor) && !canFind( listFromFile( editors_file), editor ) ){
		addItemToListInFile( editors_file, editor, available_editors.array, true);
	  }
	  stderr.writeln("TIP: Set environment variable CURLY_EDITOR or EDITOR. f.e.: 'export CURLY_EDITOR=mcedit'");
	} 
	if (editor.empty){
	  exit(1);
	}
	
	// открыть файл в редакторе EDITOR  
	auto editCmd = "%s %s".format( editor, file);
	//stderr.writeln( editCmd);
	auto edPid = spawnShell( editCmd );
	if ( edPid.wait != 0 )
	  stderr.writefln("Was error while call editor command: %s.", editor );
	
	string fileContent = file.readText;
	string fullFilePath = executeShell( escapeShellCommand( "readlink -f " ~ file )).output;
	
}

auto available_editors(){
 auto editors = ["mcedit","emacs","vim","vi", "atom","sublimetext","nano","gedit","textadept"];
 return editors.filter!( editor => "which %s".format( editor ).executeShell.output.not!empty);
}

string userChoice ( string prompt, string[] list)
{
  auto answer = "";
  int i = 0;
  writeln( prompt );
  write("Type ");
  if ( !list.empty ) write(" type number or ");
  writeln( " text for custom and Enter:\n" );
  foreach ( number, elem; list.enumerate(1) ){
    writefln("%d: %s", number, elem);
  }
  answer = readln.strip;
  if ( matchFirst( answer, regex(`^\d+$`))){
	// user enters number
	i = answer.to!int - 1;
  }else{
	i = -1;
  }	

 if (i>=0){
  // number
  return list[i];
 }else{
  //custom
  return answer;
 }
}

void addItemToListInFile(string file, string item, string[] except, bool verbose=true ){
  exists(file) || append(file,""); // create file if need
  auto list = listFromFile(file);
  item = item.strip;
  if ( except.canFind( item)){
	return;
  }
  if ( !list.canFind( item )){
	append( file, item);
	stderr.writefln("%s was added to %s", item, file);
  }	
}

string[] listFromFile( string file ){
 string[] rv;
 if ( !exists(file) ) return rv;
 return File(file).byLineCopy.map!strip.array;
}

