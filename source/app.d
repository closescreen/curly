import std.stdio, std.path, std.algorithm, std.file, std.regex, std.string, std.array, std.conv, std.functional, std.range, std.process;
import core.stdc.stdlib, std.exception, std.getopt, std.datetime, core.thread;

void main( string[] args)
{

  bool norecursively = false; 
  bool background = false;
  auto opts = getopt(
    args,
    std.getopt.config.caseSensitive,
    "nr", "disable recursively edit", &norecursively,
    "b", "background compile", &background,
  );

  if ( opts.helpWanted)  defaultGetoptPrinter( "Usage:  %s <file.d> ".format(args[0].baseName),  opts.options );

    // имя файла создаваемой программы
	auto file = args.length > 1 ? args[1] : "";

   // Если имя файла программы *.d не указано
    if ( file.empty ){

      // installing PATH instructions:
      executeShell( "which " ~ args[0].baseName ).output.empty &&
        stderr.writefln("Please add me to PATH:\nexport PATH=$PATH:%s" , args[0].dirName );

      exit(1);
    }

    // расширение файла
    string file_ex = file.extension.enforce.ifThrown("").replaceFirst(regex(`.`),"");


    // имя программы
    auto prgname = file.baseName.replace( regex(`\..+$`), "" );

	// какой editor
	auto editor = environment.get("CURLY_EDITOR" , "").strip;
	if ( editor==args[0].baseName ){
	  stderr.writefln("Not allowed %s as CURLY_EDITOR", editor);
	  exit(1);
	}else if( editor.empty ){  
	  editor = environment.get("EDITOR" , "").strip;
	}
	
	if ( editor.empty && file.exists ){
	  if ( auto editor_from_file = file.readText.matchFirst( `^\W*CURLY_EDITOR:\s*(.+)`.regex("m") ) ){
		editor = editor_from_file[1]; 
	  }
	} 

	if ( editor.empty ){
	  editor = userChoice("Choice editor", available_editors.array );
	  stderr.writeln("TIP: Set environment variable CURLY_EDITOR or EDITOR. f.e.: 'export CURLY_EDITOR=mcedit'");
	} 

	if (editor.empty){
	  exit(1);
	}
	
	if ( !file.exists ){

	  // найти шаблоны
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

	  if (editor) 
		prgText = prgText ~ ("\n// CURLY_EDITOR: %s".format( editor));

	  std.file.write( file, prgText );
	
	} // - end of if !file.exists

    Pid editorPid;
	while( true ){	
	  auto editCmd = "%s %s".format( editor, file);
      auto lm = file.timeLastModified;
      

      if ( background ){
    	if ( editorPid is null ) 
    	  editorPid = spawnShell( "set -x; " ~ editCmd );
        
        auto state = waitModifyOrTerminated( file, lm, editorPid, 2.seconds );
		if ( state == State.Terminated ){
			auto ans2 = "(%s was closed)\nEdit %s? [y]/n/Ctrl+c ( editor was terminated )".format( editor, file).userAns;
			ans2 != "" && ans2!="y" && ans2!="Y" && exit(0);
			editorPid = spawnShell( "set -x; " ~ editCmd );
		}
		
		if ( state == State.Modifyed ){
		  stderr.writefln("%s was modified.", file);
		}

    	// read/add after edit:
        string after_edit_cmd = file.get_after_edit_note;
        if (after_edit_cmd.empty){ 
          background = false;
          continue;
        }
        
        // check-write editor note:
	    if (file.get_editor_note.empty) 
	      file.add_editor_note( editor );
	  
	    // compile:
	    if ( !after_edit_cmd.empty ) 
		  if ( file.timeLastModified != lm )
		    spawnShell("set -x; " ~ after_edit_cmd ).wait;	


      } // end if background
      

      if ( !background ){
      
        editorPid = spawnShell( "set -x; " ~ editCmd );
		editorPid.wait;

        string after_edit_cmd = file.get_after_edit_note;

    	// read/add after edit:
        if ( after_edit_cmd.empty ){ 
            after_edit_cmd = userChoice( "Command for compile/check your file %s".format( file ), [] );
            if ( !after_edit_cmd.empty )
              file.add_after_edit_note( after_edit_cmd );
        }

        // check-write editor note:
	    if (file.get_editor_note.empty) 
	      file.add_editor_note( editor );
	  
	    // compile:
	    if ( !after_edit_cmd.empty ) 
		  if ( file.timeLastModified != lm )
		    spawnShell("set -x; " ~ after_edit_cmd ).wait;	
	  
	    if (norecursively) break;
	      auto ans2 = "Continue editing? [y]/n/Ctrl+c".userAns;
	      ans2 != "" && ans2!="y" && ans2!="Y" && exit(0); 
	  }
	  
	}  // end of while
} // end of main

enum State{ Modifyed, Terminated }

State waitModifyOrTerminated( string file, SysTime oldtime, Pid pid, Duration dur ){
 while ( true ){
  Thread.sleep( dur );
  if ( file.timeLastModified != oldtime ){
	return State.Modifyed;
  }
  if ( pid.tryWait.terminated ){
	return State.Terminated;
  }
 }
}

string userAns( string quest){
 writeln( quest );
 return readln.strip;
}

auto get_editor_note( string file ){
  if ( auto found_editor = file.readText.matchFirst( `^\W*CURLY_EDITOR:\s*(.+)`.regex("m") ))
    return found_editor[1].to!string;
  else
    return "";
}

void add_editor_note( string file, string editor){
  if (editor)
    file.append( "\n// CURLY_EDITOR: %s".format( editor) );
}

string get_after_edit_note( string file ){
  if ( auto found_cmd = file.readText.matchFirst( `^\W*after-edit:\s*(.+)`.regex("m") ) )
    return found_cmd[1].to!string.replaceFirst( `%f`.regex, file );
  else
    return "";
}

void add_after_edit_note( string file, string cmd){
  if ( cmd )
    file.append( "\n" ~ "// after-edit: " ~ cmd.replaceFirst( file.regex, "%f") ~ "\n" );
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


// after-edit: dub --root=..
// CURLY_EDITOR: mcedit

