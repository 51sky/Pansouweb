import axios from 'axios';

// 网盘链接检测结果接口
export interface DiskCheckResult {
  isValid: boolean;
  message?: string;
  error?: string;
}

// 网盘检测器类
class DiskChecker {
  private timeout = 10000;
  private userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  /**
   * 检测UC网盘链接有效性
   */
  async checkUC(shareId: string): Promise<DiskCheckResult> {
    const url = `https://drive.uc.cn/s/${shareId}`;
    const headers = { 
      "User-Agent": "Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/87.0.4280.101 Mobile Safari/537.36"
    };
    
    try {
      const response = await axios.get(url, { headers, timeout: this.timeout });
      const text = response.data;
      
      const errorKeywords = ["失效", "不存在", "违规", "删除", "已过期", "被取消"];
      if (errorKeywords.some(keyword => text.includes(keyword))) {
        return { isValid: false, message: "链接已失效" };
      }
      
      if (text.includes("文件") || text.includes("分享")) {
        return { isValid: true, message: "链接有效" };
      }
      
      return { isValid: false, message: "链接无效" };
    } catch (error: any) {
      if (error.code === 'ECONNABORTED') {
        return { isValid: true, message: "检测超时，链接可能有效" };
      }
      if (error.response?.status === 404) {
        return { isValid: false, message: "链接不存在" };
      }
      return { isValid: true, message: "网络错误，链接可能有效", error: error.message };
    }
  }

  /**
   * 检测阿里云盘链接有效性
   */
  async checkAliyun(shareId: string): Promise<DiskCheckResult> {
    const apiUrl = "https://api.aliyundrive.com/adrive/v3/share_link/get_share_by_anonymous";
    const headers = { "Content-Type": "application/json" };
    const data = JSON.stringify({ share_id: shareId });
    
    try {
      const response = await axios.post(apiUrl, data, { headers, timeout: this.timeout });
      const responseJson = response.data;
      
      return { 
        isValid: Boolean(responseJson.has_pwd || responseJson.file_infos),
        message: responseJson.has_pwd ? "需要提取码" : "链接有效"
      };
    } catch (error: any) {
      return { isValid: true, message: "网络错误，链接可能有效", error: error.message };
    }
  }

  /**
   * 检测115网盘链接有效性
   */
  async check115(shareId: string): Promise<DiskCheckResult> {
    const apiUrl = "https://webapi.115.com/share/snap";
    const params = { share_code: shareId, receive_code: "" };
    
    try {
      const response = await axios.get(apiUrl, { params, timeout: this.timeout });
      const responseJson = response.data;
      
      return {
        isValid: Boolean(responseJson.state || responseJson.error?.includes('请输入访问码')),
        message: responseJson.error?.includes('请输入访问码') ? "需要访问码" : "链接有效"
      };
    } catch (error: any) {
      return { isValid: true, message: "网络错误，链接可能有效", error: error.message };
    }
  }

  /**
   * 检测夸克网盘链接有效性
   */
  async checkQuark(shareId: string): Promise<DiskCheckResult> {
    const apiUrl = "https://drive.quark.cn/1/clouddrive/share/sharepage/token";
    const headers = { "Content-Type": "application/json" };
    const data = JSON.stringify({ pwd_id: shareId, passcode: "" });
    
    try {
      const response = await axios.post(apiUrl, data, { headers, timeout: this.timeout });
      const responseJson = response.data;
      
      return {
        isValid: responseJson.message === "ok" || responseJson.message === "需要提取码",
        message: responseJson.message === "需要提取码" ? "需要提取码" : "链接有效"
      };
    } catch (error: any) {
      return { isValid: true, message: "网络错误，链接可能有效", error: error.message };
    }
  }

  /**
   * 检测123网盘链接有效性
   */
  async check123(shareId: string): Promise<DiskCheckResult> {
    const apiUrl = `https://www.123pan.com/api/share/info?shareKey=${shareId}`;
    
    try {
      const response = await axios.get(apiUrl, { 
        headers: { "User-Agent": "Mozilla/5.0" },
        timeout: this.timeout 
      });
      
      if (response.status === 403) {
        return { isValid: true, message: "链接可能有效（403错误）" };
      }
      
      const responseJson = response.data;
      return {
        isValid: Boolean(responseJson.data?.HasPwd || responseJson.code === 0),
        message: responseJson.data?.HasPwd ? "需要密码" : "链接有效"
      };
    } catch (error: any) {
      return { isValid: true, message: "网络错误，链接可能有效", error: error.message };
    }
  }

  /**
   * 检测百度网盘链接有效性
   */
  async checkBaidu(shareId: string): Promise<DiskCheckResult> {
    const url = `https://pan.baidu.com/s/${shareId}`;
    const headers = { "User-Agent": this.userAgent };
    
    try {
      const response = await axios.get(url, { headers, timeout: this.timeout });
      const text = response.data;
      
      if (text.includes("need verify")) {
        return { isValid: true, message: "需要验证" };
      }
      
      const invalidKeywords = ["分享的文件已经被取消", "分享已过期", "你访问的页面不存在"];
      if (invalidKeywords.some(keyword => text.includes(keyword))) {
        return { isValid: false, message: "链接已失效" };
      }
      
      const validKeywords = ["请输入提取码", "提取文件", "过期时间"];
      return {
        isValid: validKeywords.some(keyword => text.includes(keyword)),
        message: text.includes("请输入提取码") ? "需要提取码" : "链接有效"
      };
    } catch (error: any) {
      return { isValid: false, message: "链接检测失败", error: error.message };
    }
  }

  /**
   * 检测天翼云盘链接有效性
   */
  async checkTianyi(shareId: string): Promise<DiskCheckResult> {
    const apiUrl = "https://api.cloud.189.cn/open/share/getShareInfoByCodeV2.action";
    
    try {
      const response = await axios.post(apiUrl, { shareCode: shareId }, { timeout: this.timeout });
      const text = response.data;
      
      const invalidKeywords = ["ShareInfoNotFound", "ShareNotFound", "FileNotFound", "ShareExpiredError", "ShareAuditNotPass"];
      if (invalidKeywords.some(keyword => text.includes(keyword))) {
        return { isValid: false, message: "链接已失效" };
      }
      
      return { isValid: true, message: "链接有效" };
    } catch (error: any) {
      if (error.code === 'ECONNABORTED') {
        return { isValid: true, message: "检测超时，链接可能有效" };
      }
      return { isValid: false, message: "链接检测失败", error: error.message };
    }
  }

  /**
   * 通用网盘链接检测方法
   */
  async checkDiskLink(url: string): Promise<DiskCheckResult> {
    try {
      // 提取分享ID
      const shareId = this.extractShareId(url);
      if (!shareId) {
        return { isValid: false, message: "无效的网盘链接格式" };
      }

      // 根据URL类型调用对应的检测方法
      if (url.includes('uc.cn') || url.includes('drive.uc.cn')) {
        return await this.checkUC(shareId);
      } else if (url.includes('aliyundrive.com')) {
        return await this.checkAliyun(shareId);
      } else if (url.includes('115.com')) {
        return await this.check115(shareId);
      } else if (url.includes('quark.cn')) {
        return await this.checkQuark(shareId);
      } else if (url.includes('123pan.com')) {
        return await this.check123(shareId);
      } else if (url.includes('pan.baidu.com')) {
        return await this.checkBaidu(shareId);
      } else if (url.includes('cloud.189.cn')) {
        return await this.checkTianyi(shareId);
      } else {
        return { isValid: true, message: "未知网盘类型，无法检测" };
      }
    } catch (error: any) {
      return { isValid: true, message: "检测出错，链接可能有效", error: error.message };
    }
  }

  /**
   * 从URL中提取分享ID
   */
  private extractShareId(url: string): string | null {
    try {
      const urlObj = new URL(url);
      const pathParts = urlObj.pathname.split('/');
      
      // 获取最后一个非空路径部分
      for (let i = pathParts.length - 1; i >= 0; i--) {
        if (pathParts[i] && pathParts[i].length > 0) {
          return pathParts[i];
        }
      }
      
      return null;
    } catch {
      // 如果URL解析失败，尝试直接提取
      const match = url.match(/([a-zA-Z0-9]{8,})/);
      return match ? match[1] : null;
    }
  }

  /**
   * 批量检测网盘链接
   */
  async batchCheckLinks(urls: string[]): Promise<Map<string, DiskCheckResult>> {
    const results = new Map<string, DiskCheckResult>();
    
    // 使用Promise.all并行检测所有链接
    const promises = urls.map(async (url) => {
      const result = await this.checkDiskLink(url);
      results.set(url, result);
    });
    
    await Promise.all(promises);
    return results;
  }
}

// 创建单例实例
export const diskChecker = new DiskChecker();