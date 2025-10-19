#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <sched.h>
#include <fcntl.h>
#include <math.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <sys/ioctl.h>



#define CMA_ALLOC _IOWR('Z', 0, uint32_t)

int interrupted = 0;

void signal_handler(int sig)
{
  interrupted = 1;
}

int main ()
{
  int fd;
  int position, limit, offset;
  volatile uint32_t *rx_addr, *rx_cntr;

  volatile uint8_t *rx_rst;
  volatile void *cfg, *sts, *ram;
  cpu_set_t mask;
  struct sched_param param;

  uint32_t size;

  memset(&param, 0, sizeof(param));
  param.sched_priority = sched_get_priority_max(SCHED_FIFO);
  sched_setscheduler(0, SCHED_FIFO, &param);

  CPU_ZERO(&mask);
  CPU_SET(1, &mask);
  sched_setaffinity(0, sizeof(cpu_set_t), &mask);

  if((fd = open("/dev/mem", O_RDWR)) < 0)
  {
    perror("open");
    return EXIT_FAILURE;
  }

  cfg = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x40000000);
  sts = mmap(NULL, sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0x41000000);

  close(fd);

  if((fd = open("/dev/cma", O_RDWR)) < 0)
  {
    perror("open");
    return EXIT_FAILURE;
  }

  size = 2048*sysconf(_SC_PAGESIZE);

  if(ioctl(fd, CMA_ALLOC, &size) < 0)
  {
    perror("ioctl");
    return EXIT_FAILURE;
  }

  ram = mmap(NULL, 2048*sysconf(_SC_PAGESIZE), PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0);

  rx_rst = (uint8_t *)(cfg + 0);
  rx_addr = (uint32_t *)(cfg + 4);
  rx_cntr = (uint32_t *)(sts + 0);

  *rx_addr = size;
  
  printf("ADC test program started\n");

  while(!interrupted)
  {
    printf("IP reset...\n");
    /* enter reset mode */
    *rx_rst &= ~1;
    usleep(100);
    *rx_rst &= ~2;


    printf("IP reset is DONE\n");

    signal(SIGINT, signal_handler);

    /* enter normal operating mode */
    *rx_rst |= 2;
    usleep(100);
    *rx_rst |= 1;

    limit = 32*1024;

    uint32_t overrun_jump = 0;

    printf("Waiting for data...\n");


    int16_t a_min = +8191, b_min = +8191;
    int16_t a_max = -8191, b_max = -8191;
    int ovrn_jmp_warns = 0;

    while(!interrupted)
    {
      /* read ram writer position */
      position = *rx_cntr;

      static int last_pos = 0;
      if (position < last_pos) {
          overrun_jump = 65535 - last_pos + position;
          if (overrun_jump > 65535-20000) { // если перепрыгнули больше чем на 20000 отсчетов, то предупреждаем
            ovrn_jmp_warns++;
            printf("WARNING: overrun JUMP CNT= %i, jump= %i; %i -> %i \n", ovrn_jmp_warns, overrun_jump,  last_pos, position);
          }
      }
      last_pos = position;

      /* send 4 MB if ready, otherwise sleep 1 ms */
      if((limit > 0 && position > limit) || (limit == 0 && position < 32*1024)){
        offset = limit > 0 ? 0 : 4096*1024;
        limit = limit  > 0 ? 0 : 32*1024;
        //uint32_t *buf32 = (uint32_t *)ram;
        uint32_t *buf32 = (uint32_t *)((uint8_t *)ram + offset);

        int words_in_half = (4096*1024) / sizeof(uint32_t); // 4MB / 4 байта = 1,048,576 слов Половина буфера


          for (int i = 0; i < words_in_half; ++i) {
              uint32_t word   = buf32[i];
              //uint8_t type    = (word >> 30) & 0x3;
              //int16_t a       = (int16_t)((word >> 15) & 0x7FFF); // 15 бит
              //int16_t b       = (int16_t)(word & 0x7FFF);         // 15 бит

              int16_t a = (int16_t)(word >> 16);  // старшие 16 бит
              int16_t b = (int16_t)(word & 0xFFFF); // младшие 16 бит

              // Преобразование 15-битного знакового числа
              //if (a & 0x4000) a |= 0x8000; // sign extend
              //if (b & 0x4000) b |= 0x8000; // sign extend

              /*
              if (a < a_min){
                  a_min = a;
                  printf("A min: [%d] max: %d\n", a_min, a_max);
                  printf("B min: %d max: %d\n", b_min, b_max);
                  printf("\n");
              }

              
              if (b < b_min){
                  b_min = b;
                  printf("A min: %d max: %d\n", a_min, a_max);
                  printf("B min: [%d] max: %d\n", b_min, b_max);
                  printf("\n");
              }
                  */
              

              /*
              if (a > a_max){
                  a_max = a;
                  printf("A min: %d max: [%d]\n", a_min, a_max);
                  printf("B min: %d max: %d\n", b_min, b_max);
                  printf("\n");
              }*/

              /*
              if (b > b_max){
                  b_max = b;
                  printf("A min: %d max: %d\n", a_min, a_max);
                  printf("B min: %d max: [%d]\n", b_min, b_max);
                  printf("\n");
              }
              */
                

              //if (i<20) printf("%2d|%2u|%d|%d\n", i, type, a, b);
              if (i<20) printf("%2u|%d|%d\n", i, a, b);
          }

      }
      else
      {
        usleep(100);
      }
    }

    signal(SIGINT, SIG_DFL);    
  }

  /* enter reset mode */
  *rx_rst &= ~1;
  usleep(100);
  *rx_rst &= ~2;



  return EXIT_SUCCESS;
}
