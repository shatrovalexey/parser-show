from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import NoSuchElementException
import pandas as pd
import time

def scrape_hp_products():
    driver = webdriver.Chrome()
    
    try:
        driver.get("https://www.hp.com/kz-ru/products/ink-toner/view-all-ink-and-toner.html?is_channeladvisor=yes")

        wait = WebDriverWait(driver, 10)

        wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, ".onetrust-accept-btn-handler")))

        driver.find_element_by_css_selector('.onetrust-accept-btn-handler').click()

        wait.until(EC.element_to_be_clickable((By.CSS_SELECTOR, ".c-product-tile__title")))

        while True:
            try:
                load_more = driver.find_element_by_css_selector('[data-gtm-value="load-more"]')

                if load_more.is_displayed():
                    load_more.click()
                    print('OK')
                    time.sleep(2)
                else:
                    break
            except NoSuchElementException:
                break
        
        # Сбор названий продуктов
        products = driver.find_element_by_css_selector('.c-product-tile__title')
        product_titles = [product.text.strip() for product in products]
        
        # Сохранение в CSV
        df = pd.DataFrame({'Product Titles': product_titles})
        df.to_csv('hp_products.csv', index=False, encoding='utf-8')
        
        print(f"Найдено {len(product_titles)} продуктов")
        for title in product_titles:
            print(title)
            
    finally:
        driver.quit()

if __name__ == '__main__':
    scrape_hp_products()