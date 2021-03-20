BEGIN{
	archivo=FILENAME
};

(archivo != FILENAME){
	if (linea) 
		print linea;
	p=0;
	linea="#newfile " FILENAME;
	archivo = FILENAME
}; 

/^site/{next}

//{
	n=$4; 
	if (p == 0)
	{
		print linea > "/dev/stderr";
		printf($1 FS $2 FS);
	};
	if (n != p+1 && p != 0) 
	{
		print linea; 
		printf($1 FS $2 FS);
	}; 
	p = n; 
	linea=$2;
};

END{
	print linea;
};
