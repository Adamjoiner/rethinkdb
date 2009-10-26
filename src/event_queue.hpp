
#ifndef __EVENT_QUEUE_HPP__
#define __EVENT_QUEUE_HPP__

#include <pthread.h>
#include <libaio.h>
#include "alloc_blackhole.hpp"

// Event handling
typedef int resource_t;
enum event_type_t {
    et_disk_event, et_sock_event
};
struct event_t {
    event_type_t event_type;
    resource_t source;

    /* For event_type == et_disk_event */
    int result;   // Result of the io operation
    void *buf;    // Location of the buffer where data was copied (for read events)
};
struct event_queue_t;
typedef void (*event_handler_t)(event_queue_t*, event_t*);

// Event queue structure
struct worker_pool_t;
struct event_queue_t {
    int queue_id;
    pthread_t aio_thread;
    io_context_t aio_context;
    pthread_t epoll_thread;
    int epoll_fd;
    event_handler_t event_handler;
    alloc_blackhole_t allocator;
    worker_pool_t *parent_pool;
    volatile bool dying;
};

// Event queue initialization/destruction
void create_event_queue(event_queue_t *event_queue, int queue_id, event_handler_t event_handler,
                        worker_pool_t *parent_pool);
void destroy_event_queue(event_queue_t *event_queue);

// Event queue operation
void queue_watch_resource(event_queue_t *event_queue, resource_t resource);
void queue_forget_resource(event_queue_t *event_queue, resource_t resource);

#endif // __EVENT_QUEUE_HPP__

