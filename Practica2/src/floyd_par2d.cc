#include <iostream>
#include <fstream>
#include <string.h>
#include <sys/time.h>
#include "Graph.h"
#include "mpi.h"
#include <cmath>

using namespace std;

//**************************************************************************

int main(int argc, char *argv[])
{

	MPI::Init(argc, argv);

	if (argc != 2)
	{
		cerr << "Sintaxis: " << argv[0] << " <archivo de grafo>" << endl;
		return (-1);
	}

	Graph G;
	int nverts, rank, size;
	MPI_Comm comm_fila, comm_columna;

	MPI_Comm_rank(MPI_COMM_WORLD, &rank);
	MPI_Comm_size(MPI_COMM_WORLD, &size);

	// Read the Graph in process 0
	if (rank == 0)
	{
		G.lee(argv[1]);
		nverts = G.vertices;
	}

	// Broadcast the number of vertices to all processes
	MPI_Bcast(&nverts, 1, MPI_INT, 0, MPI_COMM_WORLD);

	int raiz_P = sqrt(size);
	int tam = nverts / raiz_P;

	MPI_Datatype MPI_BLOQUE;
	int *buf_envio = new int[nverts * nverts];

	//sincronizo y tomo la primera medida de tiempo
	MPI_Barrier(MPI_COMM_WORLD);
	double t1 = MPI_Wtime();
	int *grafo = G.Get_Matrix();

	if (rank == 0)
	{

		//Defino el tipo de bloque cuadraro
		MPI_Type_vector(tam, tam, nverts, MPI_INT, &MPI_BLOQUE);
		MPI_Type_commit(&MPI_BLOQUE);

		//Empaquetamos bloque a bloque
		for (int i = 0, posicion = 0; i < size; i++)
		{
			int fila_P = i / raiz_P;
			int columna_P = i % raiz_P;
			int comienzo = (columna_P * tam) + (fila_P * tam * tam * raiz_P);

			MPI_Pack(grafo + comienzo, 1, MPI_BLOQUE, buf_envio, sizeof(int) * nverts * nverts, &posicion, MPI_COMM_WORLD);
		}
		//Libero 
		MPI_Type_free(&MPI_BLOQUE);
	}

	int buf_recp[tam][tam];
	MPI_Scatter(buf_envio, sizeof(int) * tam * tam, MPI_PACKED, buf_recp, tam * tam, MPI_INT, 0, MPI_COMM_WORLD);

	//Creo los comunicadores necesarios para repartir con el broadcast
	MPI_Comm_split(MPI_COMM_WORLD, rank / raiz_P, rank, &comm_fila);
	MPI_Comm_split(MPI_COMM_WORLD, rank % raiz_P, rank, &comm_columna);

	int subfila_k[tam];
	int subcolumna_k[tam];

	int rank_fila = rank / raiz_P;
	int rank_columna = rank % raiz_P;
	int gis = rank_fila * tam;
	int gie = rank_fila + tam;
	int gjs = rank_columna * tam;
	int gje = gjs + tam;
	int gi, gj,num_proc;
	for (int k = 0; k < nverts; k++)
	{

		//Proceso en el que se encuentra la fila k
		num_proc = k / tam;
		//Veo en que interacciones hay que realizar el broadcast de la subfila
		//if (k >= gis && k <= gie)	
		if (num_proc == rank_fila)
			for (int i = 0; i < tam; i++)
			{
				subfila_k[i] = buf_recp[k % tam][i];
			}
		MPI_Bcast(subfila_k, tam, MPI_INT, num_proc, comm_columna);
		
		//Veo en que interacciones hay que realizar el broadcast de la subcolumna
		//if (k >= gjs && k <= gje)
		if (num_proc == rank_columna)
			for (int i = 0; i < tam; i++)
			{
				subcolumna_k[i] = buf_recp[i][k % tam];
			}
		MPI_Bcast(subcolumna_k, tam, MPI_INT, num_proc, comm_fila);

		//Realizo el algoritmo
		for (int i = 0; i < tam; i++)
		{
			//El indice global i actual
			gi = gis + i;
			for (int j = 0; j < tam; j++)
			{
				//El indice global j actual
				gj = gjs + j;
				// que no sean celdas con valor 0
				if (gi != gj && gi != k && gj != k)
					buf_recp[i][j] = min(subfila_k[j] + subcolumna_k[i],buf_recp[i][j]);
			}
		}
	}

	// Ahora realizamos un gather para recibir todos los datos de todos los procesos al proceso 0
	MPI_Gather(buf_recp, tam * tam, MPI_INT, buf_envio, sizeof(int) * tam * tam, MPI_PACKED, 0, MPI_COMM_WORLD);

	//realizamos el proceso inverso que haciamos antes del reparto
	MPI_Datatype MPI_BLOQUE_2;
	//algoritmo inverso del mpi_pack
	if (rank == 0)
	{

		//Definimos el MPI_Type que se usara en el unpack
		MPI_Type_vector(tam, tam, nverts, MPI_INT, &MPI_BLOQUE_2);
		MPI_Type_commit(&MPI_BLOQUE_2);
		for (int i = 0, posicion = 0; i < size; i++)
		{

			int fila_P = i / raiz_P;
			int columna_P = i % raiz_P;
			int comienzo = columna_P * tam + fila_P * tam * tam * raiz_P;
			MPI_Unpack(buf_envio, sizeof(int) * nverts * nverts, &posicion, grafo + comienzo, 1, MPI_BLOQUE_2, MPI_COMM_WORLD);
		}
		//Libero
		MPI_Type_free(&MPI_BLOQUE_2);
	}

	//Para asegurarnos que ya han llegado todos al final
	MPI_Barrier(MPI_COMM_WORLD);
	double t2 = MPI_Wtime();

	t2 = t2 - t1;
	if (rank == 0)
	{
		//G.imprime();
		cout << "Tiempo Floyd 2D: " << t2 << endl;
	}

	//Finalizamos MPI
	MPI_Finalize();
}
