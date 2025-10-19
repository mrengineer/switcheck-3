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
#include <time.h>
#include "xadc_temp.h"

// Установить бит n
#define SET_BIT(var, n)    ((var) |=  (1U << (n)))

// Сбросить бит n
#define CLEAR_BIT(var, n)  ((var) &= ~(1U << (n)))

// Инвертировать бит n
#define TOGGLE_BIT(var, n) ((var) ^=  (1U << (n)))

// Проверить бит n (вернёт 0 или 1)
#define CHECK_BIT(var, n)  (((var) >> (n)) & 1U)




#define clrscr() printf("\e[1;1H\e[2J")
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

  //Процесс привязывается к CPU 1 с максимальным приоритетом в режиме реального времени (SCHED_FIFO)
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


          // формируем имя файла по текущему времени
          time_t now = time(NULL);
          struct tm *t = localtime(&now);
          char filename[128];
          strftime(filename, sizeof(filename), "/tmp/%Y-%m-%d_%H_%M_%S.csv", t);

          FILE *csv = fopen(filename, "w");
          if (!csv) {
              perror("fopen");
              close(fd);
              exit(1);
          }
          fprintf(csv, "I|A|B\n");


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


    uint32_t *buf32 = (uint32_t *)ram;
    const int BUF_WORDS = size / sizeof(uint32_t);

    int last_pos = 0;


    while(!interrupted)
    {
      position = *rx_cntr; // позиция записи в буфере ПЛИС


      if (position == last_pos) {
            usleep(10);
            continue; // нет новых данных
      }

        if (position > last_pos) {
            // данные идут линейно
            for (int i = last_pos; i < position; i++) {
                uint32_t word = buf32[i];
                int16_t a = (int16_t)(word >> 16);
                int16_t b = (int16_t)(word & 0xFFFF);
                fprintf(csv, "%d|%d|%d\n", i, a, b);

                if (i < last_pos + 10) printf("%d|%d|%d\n", i, a, b);
                if (i == last_pos + 10) printf("...\n");
            }
            fflush(csv);
        } else {
            // кольцевое переполнение: сначала до конца буфера
            for (int i = last_pos; i < BUF_WORDS; i++) {
                uint32_t word = buf32[i];
                int16_t a = (int16_t)(word >> 16);
                int16_t b = (int16_t)(word & 0xFFFF);
                fprintf(csv, "%d|%d|%d\n", i, a, b);

                if (i < last_pos + 10) printf("%d|%d|%d\n", i, a, b);
                if (i == last_pos + 10) printf("...\n");
            }
            // затем с начала до текущей позиции
            for (int i = 0; i < position; i++) {
                uint32_t word = buf32[i];
                int16_t a = (int16_t)(word >> 16);
                int16_t b = (int16_t)(word & 0xFFFF);
                fprintf(csv, "%d|%d|%d\n", i, a, b);

                if (i < 10) printf("%d|%d|%d\n", i, a, b);
                if (i == 10) printf("...\n");
            }
            fflush(csv);
        }

        last_pos = position;

      /*
      if((limit > 0 && position > limit) || (limit == 0 && position < 32*1024)){
        offset = limit > 0 ? 0 : 4096*1024;
        limit = limit  > 0 ? 0 : 32*1024;        
        uint32_t *buf32 = (uint32_t *)((uint8_t *)ram + offset);

        int words_in_half = (4096*1024) / sizeof(uint32_t); // 4MB / 4 байта = 1,048,576 слов Половина буфера

          for (int i = 0; i < words_in_half; ++i) {
              uint32_t word   = buf32[i];
              //uint8_t type    = (word >> 30) & 0x3;
              //int16_t a       = (int16_t)((word >> 15) & 0x7FFF); // 15 бит
              //int16_t b       = (int16_t)(word & 0x7FFF);         // 15 бит

              int16_t a = (int16_t)(word >> 16);  // старшие 16 бит
              int16_t b = (int16_t)(word & 0xFFFF); // младшие 16 бит
               

              //if (i<20) printf("%2d|%2u|%d|%d\n", i, type, a, b);
              fprintf(csv, "%2d|%d|%d\n", i, a, b);

              if (i<10) printf("%2u|%d|%d\n", i, a, b);
              if (i==10) printf("....\n");
              //if (i>120-1 && i < words_in_half - 120 ) printf("%2u|%d|%d\n", i, a, b);
          }

      }
      else
      {
        usleep(100);
      }
      */
    }

    printf("Interrupted! Exiting...\n");
    fclose(csv);

    signal(SIGINT, SIG_DFL);
  }

  /* enter reset mode */
  *rx_rst &= ~1;
  usleep(100);
  *rx_rst &= ~2;



  return EXIT_SUCCESS;
}
