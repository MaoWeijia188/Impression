package com.maoweijia.impression.common;

/**
 * 统一响应体。
 *
 * <p>所有接口都返回这个结构，前端只需要判断 code 是否为 0。
 * 错误码表见 docs/04-API接口清单.md。
 *
 * <p>用 record 而不是普通类：不可变 + 自动生成构造/getter/equals，序列化由 Jackson 原生支持。
 */
public record ApiResponse<T>(int code, String message, T data) {

    /** 成功并携带数据。 */
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(0, "ok", data);
    }

    /** 成功且无数据。 */
    public static <T> ApiResponse<T> ok() {
        return ok(null);
    }

    /** 失败。 */
    public static <T> ApiResponse<T> fail(int code, String message) {
        return new ApiResponse<>(code, message, null);
    }
}
