module ArrayTags;

import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import std.conv;
import std.container;
//import std.random;
import std.traits;
import std.variant;
import std.typecons;
import std.datetime;
import XTools;

void main(){
	
	
}


class Tst(alias _NAME, alias _VALUES){
	mixin("private enum EN"~_NAME~" {" ~ _VALUES ~ "};" );	
	void print(alias i=0 )(){
		mixin("write(EN" ~ _NAME ~ ".min);");
	}
}


// for DMD 2.063  

/*
* Реализует коллекцию(Array) с быстрыми строковыми тегами (конвертируются в биты во время компиляции)
* для каждого элемента и доп. параметрами (через словарь)
* T = тип элемента
* TAGS = список тегов через пробел (можно на русском)
* KEYTYPE = тип ключа словаря (если real, или не указан, то словарь не используется, и не занимает места)
* VALUETYPE = тип значений словаря. по умолчанию string
* TAGSTYPE = тип для хранения тегов в каждом элементе коллекции. по умолчанию uint (32 тега). Можно указать ulong (64 тега)
* FUNCTYPE = тип возвращаемого значения для метафункции (если real, или не указан, то не используется)
* CODETYPE = тип кода для элемента в структуре Elem, увеличивается на 1 с каждым новым элементом (обычно uint или ulong)
*	(если real, или не указан, то не используется) CODETYPE нужен только для ссылок одних элементов на другие через setRef(), getRef()  
*/
class ArrayTags(T, alias TAGS, KEYTYPE = real, VALUETYPE = string, TAGSTYPE = uint, FUNCTYPE = real, CODETYPE = real ) {
	
	static if (!is( CODETYPE == real ) ) {
		private CODETYPE last_code;
	}	
	
	// конвертирует строку вида "red green blue yellow" в "red=1, green=2, blue=4, yellow=8" и.т.д. умножая на 2 каждый след. номер
	private static string ConvertToEnumValues(string str) {
		int v=1;
		string _fill(string s){
			string res = s~"="~to!string(v);  v *= 2;
			return res;
		}

		auto r1 = array( str.tr(",=:;{}", " ").split(" ").filter!("a!=\"\"").map!(a => _fill(a)) );
		if(r1.length > TAGSTYPE.sizeof * 8) throw new Exception("allowed no more "~ to!string(TAGSTYPE.sizeof * 8) ~ " tags");
		string res = to!string(r1.joiner(", "));
		return res;	
	}	
	
	mixin("private enum ENUMTAGS {" ~ ConvertToEnumValues(TAGS) ~ "};");

	// элементы коллекции
	Elem[] coll;
	
	alias coll this;
	//alias void function(ArrayTags c, int i, ref FUNCTYPE acc) FUNC;
	alias void delegate(ArrayTags c, int i, ref FUNCTYPE acc) FUNC;
	
	//private final struct Elem {
	private final struct Elem {
		T val;
		TAGSTYPE tags;		
						
		static if (!is( KEYTYPE == real ) ) {						
		VALUETYPE [ KEYTYPE ] par;					
		}
					
		static if (!is( FUNCTYPE == real ) ) {// три параметра: ArrayTags, индекс текущего элемента, ref FUNCTYPE (принимается и выдается)											
			FUNC func; 						
		}
						
		static if (!is( CODETYPE == real ) ) {
			CODETYPE code;
		}				
												
		alias val this;
	}						
			
	// добавляет(isSetTags == true) или убирает теги. выполняется на этапе компиляции. CTFE  	
	private static string _tags(alias S, alias PREFIX)(bool isSetTags){

		string r;
		string[] arr = S.split();
		bool isfind;
		
		foreach (s; arr) {
			isfind=false;								

			foreach(v; EnumMembers!ENUMTAGS )
			{					
				if(s == to!string(v)) {
					 if(isSetTags){ 	
					 	r ~=  PREFIX ~ ".tags |= ENUMTAGS." ~ s ~ ";" ;						 	
					 }	
					 else {
					 	r ~=  PREFIX ~ ".tags |= ENUMTAGS." ~ s ~ ";" ;
					 	r ~=  PREFIX ~ ".tags ^= ENUMTAGS." ~ s ~ ";" ;
					 }
					 isfind=true;
				}
			}
			if(!isfind) throw new Exception("tags: value '" ~ s ~"' not found in Enum 'ENUMTAGS'" );
		}				
		return r;
	}
			
	// проверяет, установлены ли теги. выполняется на этапе компиляции. CTFE  		
	private static string _isSetTags(alias S, alias PREFIX)(){
		
		string r;
		string[] arr = S.split();
		bool isfind;
		
		foreach (s; arr) {
			isfind=false;								

			foreach(v; EnumMembers!ENUMTAGS )
			{					
				if(s == to!string(v)) {
					
					if(r.length > 0) r~= " && "; 	
					r~="(("~ PREFIX ~ ".tags & ENUMTAGS." ~ s ~ ") != 0)" ;
					
					isfind=true;
				}
			}
			if(!isfind) throw new Exception("isSetTag: value '" ~ s ~ "' not found in Enum 'ENUMTAGS'" );
		}				
		if(r=="") r="true";
		return "return " ~ r ~ ";";	
	}			
		
	/**
	Устанавливает теги у элемента с индексом index.
	Если index не указан, теги устанавливаются у последнего элемента
	*/		
	TAGSTYPE setTag(alias S)(int index=-1){
		if(index == -1) index = coll.length-1;			
		mixin( _tags!(S, "coll[index]")(true) );
		return coll[index].tags;	
	}	
	
	/**	Убирает теги  */
	void removeTag(alias S)(int index){			
		mixin( _tags!(S, "coll[index]" )(false) );	
	}
	
	/** Проверяет, установлены ли теги */	
	bool isSetTag(alias S)(int index){			
		mixin( _isSetTags!(S, "coll[index]") );
	} 			 			
	
	/** Добавляет элемент, возможно сразу с тегами */		
	int add(alias S="")(T v){
		Elem el = Elem(v);
		mixin( _tags!(S, "el")(true) );
		static if (!is( CODETYPE == real ) ) {
			el.code = getNewCode();			
		}
		coll ~= el;		
		return coll.length-1;
	}
	
	/** добавляет значения из другой коллекции в ArrayTags */
	int add(alias S="")(Elem[] arr){
		foreach (v; arr) {
			v.tags = 0;
			add!(S)(v);
		}
		return coll.length-1;
	}
	
	/** добавляет значения из массива */
	int add(alias S="")(T[] arr){
		foreach (v; arr) {
			add!(S)(v);
		}
		return coll.length-1;
	}	

	static if (!is( CODETYPE == real ) ) {
		private pure final CODETYPE getNewCode(){
			last_code++;
			if(last_code == CODETYPE.max) throw new Exception("New code for Elem reached maximum limit number");
			return last_code;
		}
	}

	/**
	* получает массив значений, фильтруя коллекцию по тегам
	*/	
	T[] getValuesByTags(alias S)(){
		T[] res;				
		foreach (i, v; coll) {
			if(isSetTag!(S)(i)){
				res ~= v.val;				
			}
		}
		return res;		
	}

	/**
	* Выполняет мета функции для каждого элемента, если заданы
	*/
	static if (!is( FUNCTYPE == real ) ) {	
	FUNCTYPE run(alias S = "")() 	
	{
		FUNCTYPE r;
		foreach (i, v; coll) {
			if(isSetTag!(S)(i)){
			 	if(v.func !is null)
			 	   v.func(this, i, r);			
			} 	   
		}
		return r;
	}
	}
	
	/**
	Выполняет мета функции для каждого элемента, если заданы, и funcCustom если не заданы
	формат функции: void delegate(ArrayTags c, int i, ref FUNCTYPE acc)
	*/	
	static if (!is( FUNCTYPE == real ) ) {	
	FUNCTYPE run(alias S = "")(FUNC funcCustom) 	
	{
		FUNCTYPE r;
		foreach (i, v; coll) {
			if(isSetTag!(S)(i)){
			    if(v.func !is null)
			      v.func(this, i, r);
			    else
			      funcCustom(this, i, r);
		    }			
		}
		return r;
	}
	}
	
	/** создает копию объекта
	*/
	ArrayTags dup(){
		ArrayTags at = new ArrayTags!( T,TAGS,KEYTYPE,VALUETYPE,TAGSTYPE,FUNCTYPE,CODETYPE );										
		at.coll = coll.dup;						
		return at;
	}
	
	/** создает копию объекта с фильтром элементов по указанным тегам
	*/
	ArrayTags dupFilterByTags(alias S)(){
		ArrayTags at = new ArrayTags!( T, TAGS, KEYTYPE, VALUETYPE, TAGSTYPE, FUNCTYPE, CODETYPE );
		foreach (i,ref v; coll) {
			if(isSetTag!(S)(i)){
				at.coll ~= coll[i];				
			}			
		}		
		return at;
	}
	
	// корректирует ссылки на индексы, что содержатся по всему массиву в ключах parName
	// учитывается что с индекса index было вставлено (count положительный) или удалено(отрицательный) count элементов
	// возвращает количество исправленных ссылок
	int repairIndexRefs(int index, int count, string parName){
		// TODO
		return 0;
	}
	
	// корректирует ссылки на индексы, что содержатся по всему массиву в ключах parNames (произвольное колво)
	void repairIndexRefs(string[] parNames...){		
		foreach(parName; parNames)
			foreach (i,v; coll) {			
					getRef(i, parName);
				}
	}
	
	// для хранения ссылки на элемент
	private struct refElem {
		int index;
		CODETYPE code;
	}		

	// если формат значения параметров Variant или refElem и код элемента используется
	static if((is(VALUETYPE == Variant) || is(VALUETYPE == refElem)) && !is(CODETYPE == real )){
		
		/** устанавливает в элементе с индексом index, в параметр parName, ссылку на элемент с индексом indexRef
		(внутренний формат значения ссылки особый: индекс и код. ) */
		void setRef(int index, string parName, int indexRef)	
		{
			coll[index].par[parName] = refElem( indexRef, coll[indexRef].code );		
		}		
				
							
		/** получает индекс элемента, на который ссылается значение в parName (для элемента c индексом index)
		 (формат значения ссылки особый: индекс и код. ) структурой
		 поиск происходит по след. алгоритму: берется  индекс из parName, и у этого элементва проверяется код на равенство
		 с кодом parname. если равен, возвращается элемент. Если нет, ищется вокруг по индексам, с возрастающей амплитудой.
		 когда находиться, перезаписывается в parname источника новый найденный индекс. */
		int getRef(int index, string parName){
						
			auto sr = coll[index].par[parName];
			if(!is(typeof(sr) == refElem )) throw new Exception("par[" ~ parName ~ "] not contains struct refElem");
			
			if(coll[sr.index].code == sr.code ) return sr.index;
			
			int indDown=sr.index, indUp=sr.index;
			while(indDown > 0 || indUp < coll.length-1){
				if(indDown > 0) {
					 indDown--;
					 if(coll[indDown].code == sr.code ) { coll[index].par[parName].index = indDown; return sr.index; }
				}
				
				if(indUp < coll.length-1) {
					indUp++;
					if(coll[indUp].code == sr.code ) { coll[index].par[parName].index = indUp; return sr.index; }
				}				
			}
						
			return -1; // элемент не найден
		}
	}
	
	static if(is(VALUETYPE == string) && !is(CODETYPE == real )){
		
		void setRef(int index, string parName, int indexRef)	
		{
			coll[index].par[parName] = to!string(indexRef) ~ " " ~ to!string( coll[indexRef].code );
		}		
		
		int getRef(int index, string parName){
						
			auto sr = coll[index].par[parName];
			if(!is(typeof(sr) == string )) throw new Exception("par[" ~ parName ~ "] not contains string");
			
			//int[] ic = sr.split.map!"to!int(a)".array; // тоже вариант!!!
			//int[] ic = array( sr.split.map!"to!int(a)" ); // TODO сравнить скорость с вариантом ниже			
			//int sr_index = ic[0], sr_code = ic[1];
			
			string[] sic = sr.split;			 
			int sr_index = to!int(sic[0]), sr_code = to!int(sic[1]);
			
			if(coll[sr_index].code == sr_code ) return sr_index;
			
			int indDown=sr_index, indUp=sr_index;
			while(indDown > 0 || indUp < coll.length-1){
				if(indDown > 0) {
					 indDown--;
					 if(coll[indDown].code == sr_code ) { coll[index].par[parName] = to!string(indDown)~" "~to!string(sr_code); return sr_index; }
				}
				
				if(indUp < coll.length-1) {
					indUp++;
					if(coll[indUp].code == sr_code ) { coll[index].par[parName] = to!string(indUp)~" "~to!string(sr_code); return sr_index; }
				}				
			}
						
			return -1; // элемент не найден
		}
	}	
		
	int insert(alias S="")(int index, T v){
		Elem el = Elem(v);
		mixin( _tags!(S, "el")(true) );
		static if (!is( CODETYPE == real ) ) {
			el.code = getNewCode();			
		}
		coll = coll[0..index] ~ el ~ coll[index..$];		
		return index;
	}
	
	int insert(alias S="")(int index, T[] arr){
		
		Elem[] newElems;
		foreach (v; arr) {

			Elem el = Elem(v);
			el.tags = 0;
			mixin( _tags!(S, "el")(true) );
			static if (!is( CODETYPE == real ) ) {
				el.code = getNewCode();			
			}
			newElems ~= el;
		}
			
		coll = coll[0..index] ~ newElems ~ coll[index..$];		
		return index + newElems.length;
	}
	
	int insert(alias S="")(int index, Elem[] arr){
		
		foreach (ref el; arr) {
			el.tags = 0;
			mixin( _tags!(S, "el")(true) );
			static if (!is( CODETYPE == real ) ) {
				el.code = getNewCode();			
			}
		}
			
		coll = coll[0..index] ~ arr ~ coll[index..$];		
		return index + arr.length;
	}	
			
// // недоделанный вариант удаления нескольких элеметнов		
//	void remove(int index, int size=1){
//		assert( index <= coll.length - 1 );		
//		if(index == coll.length - 1) {
//			coll = coll[0..$-1];
//			return;			
//		}
//		
//		if( coll.length - 1 < index + size ) { 
//			size = coll.length-1 - index; 
//		};
//		coll = coll[0..index] ~ coll[ index+size .. $];		
//	}
		
	/** удаляет элемент с индексом index
	*/	
	void remove(int index){
		assert( index <= coll.length - 1 );		
		if(index == coll.length - 1) {
			coll = coll[0..$-1];
			return;			
		}		
		coll = coll[0..index] ~ coll[ index+1 .. $];		
	}				
		
		
	struct ItemsResult {
		
		Elem ** first;
		Elem ** last;		
        
        @property bool empty()
        {
            if(first==null || last==null) return true;
            return first > last ? true : false;            
        }
        
        void popFront()
        {
        	first = &first[1];
        }

        @property ref Elem front()
        {
        	return *first[0];
        }		
	}	
			
	/**
	Возвращает последовательность элементов для перебора foreach для обхода по определенным (или всем) тегам. 
	теги указываются в S, элементы передаются по ссылке
	*/		
	ItemsResult items(alias S="")(){
		// TODO OPTIMIZE
	
		Elem * [] _coll;
		foreach (i,ref v; coll) {
			if(isSetTag!(S)(i)){
				_coll ~= &v; 
			}
		}
		if(_coll.length == 0) return ItemsResult(null, null);
	
		return ItemsResult(&_coll[0], &_coll[$-1]);
		
	}
}		
	// сделать методы установки тэгов из структуры Elem		
	
	// сдеалать генерацию связей в иерархи (через par) на основании указанной структуры вложенности тегов 
	// например - generateLinks("parName", "red (yellow white ( green ) ) "); // продумать как иерархия будет
	 

unittest{
	
	//writeln("\n=== ArrayTags unittest ===");
	auto c = new ArrayTags!(int, "red green blue cyan magenta white black obsidian pearl", string, string, ulong, string, ulong);  // можно и по русски теги писать			
		
	int i = c.add!"green"(4);	// добавляем знач. 4 с тегом "green", и получаем индекс элемента в коллекции
	
	c.setTag!"red blue"(i); // добавляем еще теги (по индексу)
	c.setTag!"black"; // а так - для последнего элемента коллекции устанавливает теги
	//writeln(c[i]);
	assert( c[i] == 4 );
			
	c[$-1] = 7;	// изменяем значение через индекс коллекции
	c.back.par["command"] = "go!";
	assert( c.back == 7 );
	assert( c[$-1].par["command"] == "go!" );
	string s="";	
	int iii=0;
	c.FUNC ff = (a, ind, ref b) { };
	//c.back.func = ff;
	c.back.func = (a, ind, ref b) { b ~= "func1 " ~ to!string(ind); }; // a, ind, ref c = псевдонимы для использования
	// a - сам объект ArrayTags, ind - индекс текущего элемента, b = результат, может использоваться при функции run
	c.back.func (c, iii, s); // выполняем функцию, назначенную элементу
	//write( s );
	assert(s == "func1 0" );
	
	c[$-1].par["word"]="some";	 
	c.removeTag!"blue"(i); // удаляем тег "blue"
			
	assert( c.isSetTag!"green"(0) == true ); // установлен ли тег "green" у первого элемента
 
	c.add!"obsidian pearl"(8);
    c.add!"red pearl"(9);
    c.back.func = (a, ind, ref b) { b ~= " func2 " ~ ind.str; };
    auto r = c.getValuesByTags!"red";
    assert(r == [7, 9] ); 
    
    assert( c.run!() == "func1 0 func2 2" ); // выполним функции, у тех элеметнов, у которых они есть.   
    
    auto nc = c.dup();        
        
    assert( nc[0].par["word"] = "some");
    assert( nc.run() == "func1 0 func2 2" );
    	
	nc.add([1,2,3]);
	nc.setTag!("black");
    r = nc.getValuesByTags!"black";
    assert(r == [7,3]); 	
	
	// dupFilterByTags	
	auto vv = nc.dupFilterByTags!"black";
	assert( vv[] == [7,3] );
		
	nc.setRef(5, "ref", 2);
	//nc.insert!"magenta"( 2, 777 ); 
	//nc.remove(2); 
	//writeln( nc ); // !!! разобраться с причиной ошибки, когда после выполнения этой команды writeln( nc[5] ) начинает выдавать ошибку!
	//writeln( nc.getRef(5, "ref") );
	//writeln( nc[5] );
		
	nc.add(c[]);
	nc.insert(1, c[]);
	//writeln( nc[] );
		
	foreach (ref v; nc.items!"obsidian") {
		v = 77;		
	}
	
	//writeln( nc[] );
				
	//writefln(" %8.8f ", to!double("22279872,650003323".tr(",",".")));	
	
}