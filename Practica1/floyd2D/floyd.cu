#include <iostream>
#include <fstream>
#include <string.h>
#include <sys/time.h>
#include "Graph.h"

// CUDA runtime
//#include <cuda_runtime.h>

// helper functions and utilities to work with CUDA
//#include <helper_functions.h>
//#include <helper_cuda.h>

#define blocksize 1024

using namespace std;

//**************************************************************************
double cpuSecond()
{
	struct timeval tp;
	gettimeofday(&tp, NULL);
	return((double)tp.tv_sec + (double)tp.tv_usec*1e-6);
}
// Version 1D
//**************************************************************************
__global__ void floyd_kernel(int * M, const int nverts, const int k) {
	int ij = threadIdx.x + blockDim.x * blockIdx.x;
	if (ij < nverts * nverts) {
		int Mij = M[ij];
		int i= ij / nverts;
		int j= ij - i * nverts;
		if (i != j && i != k && j != k) {
				int Mikj = M[i * nverts + k] + M[k * nverts + j];
			Mij = (Mij > Mikj) ? Mikj : Mij;
			M[ij] = Mij;
			}
	}
}
// Versión 2D
__global__ void floyd_kernel_2D(int * M, const int nverts, const int k) {
	int i = threadIdx.y + blockDim.y * blockIdx.y;
	int j = threadIdx.x + blockDim.x * blockIdx.x;
	
	if ( i < nverts && j < nverts ) {
		int indice = j + nverts * i; 
		int Mindice = M[indice];
   		if (i != j && i != k && j != k) {
			int Mikj = M[i * nverts + k] + M[k * nverts + j];
			Mindice = (Mindice > Mikj) ? Mikj : Mindice;
			M[indice] = Mindice;
		}
	}
}
__global__ void reduceSum(int *d_V, int n)
{
  extern __shared__ int sdata[blocksize];

  int tid = threadIdx.x;
  int i = blockIdx.x * blockDim.x + threadIdx.x;

	  if (i < n){ 
    
		sdata[tid] = d_V[i];

		__syncthreads();

		for (int s = blockDim.x; s > 0; s >>= 1)
		{
			if (tid < s)
			{
			sdata[tid] = (sdata[tid] > sdata[tid+s] ? sdata[tid] : sdata[tid+s]);
			}
			__syncthreads();
		}
	}
  if (tid == 0){
	d_V[blockIdx.x] = sdata[0];
  }
}

int main (int argc, char *argv[]) {

	if (argc != 2) {
		cerr << "Sintaxis: " << argv[0] << " <archivo de grafo>" << endl;
		return(-1);
	}
	

  //Get GPU information
  int devID;
  cudaDeviceProp props;
  cudaError_t err;
  err = cudaGetDevice(&devID);
  if(err != cudaSuccess) {
		cout << "ERRORRR" << endl;
	}


cudaGetDeviceProperties(&props, devID);
  printf("Device %d: \"%s\" with Compute %d.%d capability\n", devID, props.name, props.major, props.minor);

	Graph G;
	G.lee(argv[1]);// Read the Graph

	//cout << "EL Grafo de entrada es:"<<endl;
	//G.imprime();
	const int nverts = G.vertices;
	const int niters = nverts;

	const int nverts2 = nverts * nverts;

	int *c_Out_M = new int[nverts2];
	int size = nverts2*sizeof(int);
	int * d_In_M = NULL;

	err = cudaMalloc((void **) &d_In_M, size);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
	}

	int *A = G.Get_Matrix();

	// GPU phase
	double  t1 = cpuSecond();

	err = cudaMemcpy(d_In_M, A, size, cudaMemcpyHostToDevice);
	if (err != cudaSuccess) {
		cout << "ERROR COPIA A GPU" << endl;
	}
	int threadsPerBlock = blocksize;
	int blocksPerGrid = (nverts2 + threadsPerBlock - 1) / threadsPerBlock;
	for(int k = 0; k < niters; k++) {
		//printf("CUDA kernel launch \n");
	 	

	  floyd_kernel<<<blocksPerGrid,threadsPerBlock >>>(d_In_M, nverts, k);
	  err = cudaGetLastError();

	  if (err != cudaSuccess) {
	  	fprintf(stderr, "Failed to launch kernel! ERROR= %d\n",err);
	  	exit(EXIT_FAILURE);
		}
	}

	cudaMemcpy(c_Out_M, d_In_M, size, cudaMemcpyDeviceToHost);
	cudaDeviceSynchronize();
	double Tgpu = cpuSecond()-t1;

	cout << "Tiempo gastado GPU= " << Tgpu << endl;


	//Ejecución del kernel 2D
	int *B = G.Get_Matrix();
	int *c_Out_M_2D = new int[nverts2];
	int * d_In_M_2D = NULL;
	
	err = cudaMalloc((void **) &d_In_M_2D, size);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
	}
	
	t1 = cpuSecond();
	err = cudaMemcpy(d_In_M_2D, B, size, cudaMemcpyHostToDevice);
	if (err != cudaSuccess) {
		cout << "ERROR COPIA A GPU" << endl;
	}

	dim3 threads_2D (32, 32);
	dim3 blocks_2D( ceil ((float)(nverts)/threads_2D.x), ceil ((float)(nverts)/threads_2D.y) );
	for(int k=0; k < niters; k++) {
	 	
		floyd_kernel_2D<<<blocks_2D,threads_2D >>>(d_In_M_2D, nverts, k);

		err = cudaGetLastError();

		if (err != cudaSuccess) {
			fprintf(stderr, "Failed to launch kernel! ERROR= %d\n",err);
			exit(EXIT_FAILURE);
		}
	}
	cudaMemcpy(c_Out_M_2D, d_In_M_2D, size, cudaMemcpyDeviceToHost);
	cudaDeviceSynchronize();

	double Tgpu_2D = cpuSecond()-t1;

	cout << "Tiempo gastado GPU en 2D= " << Tgpu_2D << endl;
	// CPU phase
	t1 = cpuSecond();

	// BUCLE PPAL DEL ALGORITMO
	int inj, in, kn;
	for(int k = 0; k < niters; k++) {
          kn = k * nverts;
	  for(int i=0;i<nverts;i++) {
			in = i * nverts;
			for(int j = 0; j < nverts; j++)
	       			if (i!=j && i!=k && j!=k){
			 	    inj = in + j;
			 	    A[inj] = min(A[in+k] + A[kn+j], A[inj]);
	       }
	   }
	}

	double t2 = cpuSecond() - t1;
	cout << "Tiempo gastado CPU= " << t2 << endl;
	cout << "Ganancia GPU_1d sobre CPU= " << t2 / Tgpu << endl;
	cout << "Ganancia GPU_2d SOBRE CPU=" << t2 / Tgpu_2D << endl;
	cout << "Ganancia GPU_1d SOBRE GPU_2D=" << Tgpu / Tgpu_2D << endl;
		
	cudaMemcpy(d_In_M_2D,c_Out_M_2D , size, cudaMemcpyHostToDevice);
	int bloquesR = ceil(float(nverts2)/blocksize);

	reduceSum<<<bloquesR,blocksize>>>(d_In_M_2D,nverts2);
	cudaMemcpy(c_Out_M_2D,d_In_M_2D , size, cudaMemcpyDeviceToHost);
	cudaDeviceSynchronize();
 
	int longitud = c_Out_M_2D[0];
	for(int i = 1; i < bloquesR;i++){
		longitud=(c_Out_M_2D[i] > longitud ? c_Out_M_2D[i]:longitud);
	}

	cout << "La longitud del camino es: " << longitud << endl;


	for(int i = 0; i < nverts; i++)
		for(int j = 0;j < nverts; j++)
			if (abs(c_Out_M[i*nverts+j] - G.arista(i,j)) > 0)
				cout << "Error (" << i << "," << j << ")   " << c_Out_M[i*nverts+j] << "..." << G.arista(i,j) << endl;

}
