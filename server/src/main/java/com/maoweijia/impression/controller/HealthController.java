package com.maoweijia.impression.controller;

import com.maoweijia.impression.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 健康检查接口（M1 / T-10）。
 *
 * <p>它只验证一件事：HTTP 请求能打到 Spring 容器并正确返回 JSON。
 * 不碰数据库 —— 所以它通了，说明「项目能启动 + Web 层正常 + Jackson 序列化正常」，
 * 与你后面要写的业务代码无关。
 *
 * <p>验证方式：浏览器或 curl 访问 http://localhost:8080/api/health
 */
@RestController
@RequestMapping("/api")
public class HealthController {

    @GetMapping("/health")
    public ApiResponse<Map<String, Object>> health() {
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("status", "up");
        data.put("service", "impression");
        data.put("javaVersion", System.getProperty("java.version"));
        data.put("time", LocalDateTime.now().toString());
        return ApiResponse.ok(data);
    }
}
