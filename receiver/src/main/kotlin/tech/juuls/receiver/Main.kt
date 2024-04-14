package tech.juuls.receiver

import com.rabbitmq.client.ConnectionFactory
import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.response.*
import io.ktor.server.routing.*

const val QUEUE_NAME = "hello"

fun main() {
    val factory = ConnectionFactory()
    factory.host = System.getenv("RABBITMQ_HOST") ?: "localhost"

    factory.newConnection().use {  connection ->
        connection.createChannel().use { channel ->
            channel.queueDeclare(QUEUE_NAME, false, false, false, null)
        }
    }

    embeddedServer(Netty, port = 80) {
        routing {
            get {
                factory.newConnection().use { connection ->
                    connection.createChannel().use { channel ->
                        channel.basicGet(QUEUE_NAME, true)?.let { message ->
                            call.respondText(message.body.decodeToString())
                        } ?: run {
                            call.respondText("No messages")
                        }
                    }
                }
            }
        }
    }.start(wait = true)
}