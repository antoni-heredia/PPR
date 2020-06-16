/* ******************************************************************** */
/*                Algoritmo Branch-And-Bound Paralelo                   */
/* ******************************************************************** */
#include <cstdlib>
#include <cstdio>
#include <iostream>
#include <mpi.h>
#include "libbb.h"

using namespace std;

unsigned int NCIUDADES;
int rank, size;

main(int argc, char **argv)
{

	MPI_Init(&argc, &argv);
	MPI_Comm_size(MPI_COMM_WORLD, &size);
	MPI_Comm_rank(MPI_COMM_WORLD, &rank);

	switch (argc)
	{
	case 3:
		NCIUDADES = atoi(argv[1]);
		break;
	default:
		cerr << "La sintaxis es: bbpar <tamanio> <archivo>" << endl;
		exit(1);
		break;
	}

	int **tsp0 = reservarMatrizCuadrada(NCIUDADES);
	tNodo nodo,	  // nodo a explorar
		lnodo,	  // hijo izquierdo
		rnodo,	  // hijo derecho
		solucion; // mejor solucion
	bool activo,  // condicion de fin
		nueva_U;  // hay nuevo valor de c.s.
	int U;		  // valor de c.s.
	int iteraciones = 0;
	tPila pila; // pila de nodos a explorar

	U = INFINITO; // inicializa cota superior

	//comunicadores
	extern MPI_Comm comunicadorCarga;
	extern MPI_Comm comunicadorCota;

	MPI_Comm_dup(MPI_COMM_WORLD, &comunicadorCarga);
	MPI_Comm_dup(MPI_COMM_WORLD, &comunicadorCota);

	extern int siguiente, anterior;
	extern bool token_presente;

	siguiente = (rank + 1) % size;
	anterior = (rank - 1 + size) % size;

	double t = MPI::Wtime();
	//leemos el problema inicial
	activo = false;

	if (rank == 0)
	{
		LeerMatriz(argv[2], tsp0); // lee matriz de fichero
		InicNodo(&nodo);		   // inicializa estructura nodo

		// Difusión matriz del problema inical del proceso 0 al resto
		MPI_Bcast(&tsp0[0][0], NCIUDADES * NCIUDADES, MPI_INT, 0, MPI_COMM_WORLD);
		token_presente = true;
	}

	//equilibramos la carga
	if (rank != 0)
	{
		MPI_Bcast(&tsp0[0][0], NCIUDADES * NCIUDADES, MPI_INT, 0, MPI_COMM_WORLD);
		//solo el proceso 0 tiene el token
		token_presente = false;
		//realizamos el equilibrado de carga
		Equilibrado_Carga(pila, activo, solucion);
		if (!activo)
			pila.pop(nodo);
		
	}

	

	while (!activo)
	{ // ciclo del Branch&Bound
		Ramifica(&nodo, &lnodo, &rnodo, tsp0);
		nueva_U = false;
		if (Solucion(&rnodo))
		{
			if (rnodo.ci() < U)
			{ // se ha encontrado una solución mejor
				U = rnodo.ci();
				nueva_U = true;
				CopiaNodo(&rnodo, &solucion);
			}
		}
		else
		{ //  no es un nodo solucion
			if (rnodo.ci() < U)
			{ //  cota inferior menor que cota superior+
				if (!pila.push(rnodo))
				{
					printf("Error2: pila agotada\n");
					liberarMatriz(tsp0);
					exit(1);
				}
			}
		}
		if (Solucion(&lnodo))
		{
			if (lnodo.ci() < U)
			{ // se ha encontrado una solucion mejor
				U = lnodo.ci();
				nueva_U = true;
				CopiaNodo(&lnodo, &solucion);
			}
		}
		else
		{ // no es nodo solucion
			if (lnodo.ci() < U)
			{ // cota inferior menor que cota superior
				if (!pila.push(lnodo))
				{
					printf("Error1: pila agotada\n");
					liberarMatriz(tsp0);
					exit(1);
				}
			}
		}
		//DIfundimos la cota superior
		//Difusion_Cota_Superior(U, nueva_U);
		if (nueva_U)
			pila.acotar(U);
		//equilibramos la carga
		Equilibrado_Carga(pila, activo, solucion);

		//comprobamos que se haya llegado al final
		if (!activo)
		{
			pila.pop(nodo);
		}

		iteraciones++;
	}
	t = MPI::Wtime() - t;
	MPI::Finalize();
	
	if (rank == 0)
	{
		printf("Solucion: \n");
		EscribeNodo(&solucion);
		cout << "Tiempo gastado= " << t << endl;

	}
			cout << "Numero de iteraciones = " << iteraciones << endl
			 << endl;
	liberarMatriz(tsp0);
}
